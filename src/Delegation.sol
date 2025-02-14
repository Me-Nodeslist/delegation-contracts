// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "./interfaces/IDelegation.sol";
import "./interfaces/ISettlement.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Delegation is
    IDelegation,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    string public constant version = "0.1.0";

    /// @notice LicenceNFT contract address
    address public licenseNFT;
    /// @notice Settlement contract address
    address public settlement;

    uint8 public maxCommissionRate;
    /// @notice Indicates how long it takes for the node to modify the rate again
    uint8 public commissionRateModifyTimeLimit;
    /// @notice How many licenses a node can delegate
    uint16 public maxDelegationAmount;
    uint32 public nodeIndex;

    mapping(address => NodeInfo) nodeInfos; // node address -> node infomation
    mapping(address => uint16) public delegationAmount; // node address -> amount of delegation received
    mapping(uint256 => address) public delegation; // nft token ID -> node address
    mapping(uint256 => RewardInfo) rewardInfos; // nft token ID -> reward information
    mapping(uint32 => uint32) public dailyDelegations; // date index -> active license delegations
    mapping(address => mapping(uint32 => uint32)) public nodeDailyDelegations; // node address -> date index -> active license delegations

    modifier onlyLicenseOwner(uint256 tokenID) {
        require(
            msg.sender == IERC721(licenseNFT).ownerOf(tokenID),
            "Not owner"
        );
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        address _licenseNFT,
        address _settlement,
        uint8 _maxCommissionRate,
        uint8 _commissionRateModifyTimeLimit,
        uint16 _maxDelegationAmount
    ) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        licenseNFT = _licenseNFT;
        settlement = _settlement;

        maxCommissionRate = _maxCommissionRate;
        commissionRateModifyTimeLimit = _commissionRateModifyTimeLimit;
        maxDelegationAmount = _maxDelegationAmount;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
     * @notice For node register, after register, node can startup, and then need to send 'updateNodeDailyDelegations()' tx daily
     * @param commissionRate The node's commission rate, delegation service fee
     * @param recipient Claim rewards to the recipient
     * @param tokenIDs The license nft id
     */
    function nodeRegister(
        uint8 commissionRate,
        address recipient,
        uint256[] calldata tokenIDs
    ) external {
        require(commissionRate <= maxCommissionRate, "Rate too large");
        nodeIndex++;
        NodeInfo storage nodeInfo = nodeInfos[msg.sender];
        nodeInfo.id = nodeIndex;
        nodeInfo.lastConfirmDate = _todayIndex() - 1;
        nodeInfo.commissionRate = commissionRate;
        nodeInfo.commissionRateLastModifyAt = block.timestamp;
        nodeInfo.recipient = recipient;

        if (tokenIDs.length > 0) {
            delegate(tokenIDs, msg.sender);
        }

        if(delegationAmount[msg.sender] > 0){
            nodeInfo.active = true;
        }

        emit NodeRegister(msg.sender, recipient, commissionRate);
    }

    function delegate(uint256[] calldata tokenIDs, address to) public {
        require(tokenIDs.length > 0, "No license");
        for (uint8 i = 0; i < tokenIDs.length; i++) {
            _delegate(tokenIDs[i], to);
        }
    }

    function undelegate(uint256 tokenID) external onlyLicenseOwner(tokenID) {
        address old = delegation[tokenID];
        require(old != address(0), "Not delegated");

        _adjustNodeDailyDelegations(old, false);
        confirmNodeReward(old);

        delegation[tokenID] = address(0);
        delegationAmount[old]--;

        if (delegationAmount[old] == 0) {
            nodeInfos[old].active = false;
        }

        rewardInfos[tokenID].totalRewards +=
            nodeInfos[old].delegationRewards -
            rewardInfos[tokenID].initialRewards;

        emit Undelegate(tokenID, old);
    }

    function redelegate(
        uint256 tokenID,
        address to
    ) external onlyLicenseOwner(tokenID) {
        address old = delegation[tokenID];
        require(old != address(0) && to != old, "Not delegated or same node");
        require(delegationAmount[to] < maxDelegationAmount, "Exceed limit");

        _adjustNodeDailyDelegations(old, false);
        confirmNodeReward(old);
        _adjustNodeDailyDelegations(to, true);
        confirmNodeReward(to);

        delegation[tokenID] = to;
        delegationAmount[old]--;
        if (delegationAmount[old] == 0) {
            nodeInfos[old].active = false;
        }
        delegationAmount[to]++;

        rewardInfos[tokenID].totalRewards +=
            nodeInfos[old].delegationRewards -
            rewardInfos[tokenID].initialRewards;
        rewardInfos[tokenID].initialRewards = nodeInfos[to].delegationRewards;

        emit Redelegate(tokenID, to);
    }

    function modifyCommissionRate(uint8 commissionRate) external {
        _modifyCommissionRate(msg.sender, commissionRate);
    }

    /**
     * @notice Node claims its reward, the reward will be transferred to the recipient
     */
    function nodeClaim() external {
        NodeInfo storage nodeInfo = nodeInfos[msg.sender];
        require(nodeInfo.id > 0, "Node not exist");

        confirmNodeReward(msg.sender);

        require(
            nodeInfo.selfTotalRewards > nodeInfo.selfClaimedRewards,
            "No reward"
        );
        uint256 rewards = nodeInfo.selfTotalRewards -
            nodeInfo.selfClaimedRewards;
        nodeInfo.selfClaimedRewards = nodeInfo.selfTotalRewards;

        ISettlement(settlement).rewardWithdraw(nodeInfo.recipient, rewards);
        emit NodeWithdraw(msg.sender, rewards);
    }

    /**
     * @notice License owner who delegated to a node claims its reward.
     * @param tokenID The license nft id
     */
    function delegationClaim(uint256 tokenID) external onlyLicenseOwner(tokenID) {
        RewardInfo storage rewardInfo = rewardInfos[tokenID];

        if (delegation[tokenID] != address(0)) {
            rewardInfo.totalRewards +=
                nodeInfos[delegation[tokenID]].delegationRewards -
                rewardInfo.initialRewards;
            rewardInfo.initialRewards = nodeInfos[delegation[tokenID]]
                .delegationRewards;
        }

        require(
            rewardInfo.totalRewards > rewardInfo.claimedRewards,
            "No reward"
        );
        uint256 reward = rewardInfo.totalRewards - rewardInfo.claimedRewards;
        rewardInfo.claimedRewards = rewardInfo.totalRewards;
        ISettlement(settlement).rewardWithdraw(msg.sender, reward);

        emit ClaimReward(msg.sender, tokenID, reward);
    }

    /**
     * @notice Node sends 'updateNodeDailyDelegations()' tx daily to initialize its delegation
     */
    function updateNodeDailyDelegations(address node) external {
        require(nodeInfos[node].active, "Unactive");
        _updateNodeDailyDelegations(node);
    }

    function setMaxCommissionRate(uint8 value) external onlyOwner {
        maxCommissionRate = value;
    }

    function setCommissionRateModifyTimeLimit(uint8 value) external onlyOwner {
        commissionRateModifyTimeLimit = value;
    }

    function setMaxDelegationAmount(uint16 value) external onlyOwner {
        maxDelegationAmount = value;
    }

    function confirmNodeReward(address node) public {
        uint32 today = _todayIndex();
        NodeInfo storage nodeInfo = nodeInfos[node];
        if (nodeInfo.id == 0 || nodeInfo.lastConfirmDate == today - 1) {
            return;
        }
        for (uint32 date = nodeInfo.lastConfirmDate + 1; date < today; date++) {
            if (
                dailyDelegations[date] == 0 ||
                nodeDailyDelegations[node][date] == 0
            ) {
                continue;
            }
            uint256 unitReward = ISettlement(settlement).totalRewardDaily(
                date
            ) / dailyDelegations[date];
            uint256 commissionReward = (unitReward * nodeInfo.commissionRate) /
                100;
            nodeInfo.selfTotalRewards +=
                commissionReward *
                nodeDailyDelegations[node][date];
            nodeInfo.delegationRewards += unitReward - commissionReward;
        }
        nodeInfo.lastConfirmDate = today - 1;
        emit ConfirmNodeReward(
            node,
            nodeInfo.selfTotalRewards,
            nodeInfo.delegationRewards
        );
    }

    function _delegate(
        uint256 tokenID,
        address to
    ) internal onlyLicenseOwner(tokenID) {
        require(delegation[tokenID] == address(0), "Delegated");
        require(delegationAmount[to] < maxDelegationAmount, "Exceed limit");

        _adjustNodeDailyDelegations(to, true);
        confirmNodeReward(to);

        delegation[tokenID] = to;
        delegationAmount[to]++;
        rewardInfos[tokenID].initialRewards = nodeInfos[to].delegationRewards;

        emit Delegate(tokenID, to);
    }

    function _modifyCommissionRate(
        address node,
        uint8 commissionRate
    ) internal {
        NodeInfo storage nodeInfo = nodeInfos[node];
        require(nodeInfo.id > 0, "Node not exist");
        require(
            nodeInfo.commissionRateLastModifyAt +
                commissionRateModifyTimeLimit <
                block.timestamp,
            "Time limit not met"
        );
        require(commissionRate <= maxCommissionRate, "Value too large");
        nodeInfo.commissionRate = commissionRate;
        nodeInfo.commissionRateLastModifyAt = block.timestamp;
        emit ModifyCommissionRate(node, commissionRate);
    }

    function _todayIndex() internal view returns (uint32) {
        return
            uint32(
                (block.timestamp - ISettlement(settlement).startTime()) /
                    (1 days)
            ) + 1;
    }

    function _updateNodeDailyDelegations(address node) internal {
        uint32 today = _todayIndex();
        if (nodeDailyDelegations[node][today] > 0) {
            return;
        }
        nodeDailyDelegations[node][today] += delegationAmount[node];
        dailyDelegations[today] += delegationAmount[node];
        emit NodeDailyDelegations(node, today, delegationAmount[node]);
    }

    function _adjustNodeDailyDelegations(address node, bool add) internal {
        uint32 today = _todayIndex();
        if (nodeDailyDelegations[node][today] == 0) {
            // node offline
            return;
        }
        if (add) {
            nodeDailyDelegations[node][today]++;
            dailyDelegations[today]++;
        } else {
            nodeDailyDelegations[node][today]--;
            dailyDelegations[today]--;
        }
    }

    function getNodeInfo(address node) external view returns (NodeInfo memory) {
        return nodeInfos[node];
    }

    function getRewardInfo(uint256 tokenID) external view returns (RewardInfo memory) {
        return rewardInfos[tokenID];
    }
}
