// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

interface IDelegation {
   /**
     * @notice The NodeInfo struct represents the information of a node
     *
     * @custom:filed id The globally unique ID of the node.
     * @custom:field active Is the node active?
     * @custom:field lastConfirmDate The date of last reward confirmation
     * @custom:filed commissionRate The rate of commission, which is given by NFT holders to the node. (Divide by 100 when calculating)
     * @custom:field claimer The address who can claim this node's reward, which is set by this node
     * @custom:filed selfTotalRewards The total rewards of the node itself
     * @custom:filed selfClaimedRewards The rewards claimed by the node itself
     * @custom:filed delegationRewards The rewards of the node’s delegator
     * @custom:filed commissionRateLastModifyAt The timestamp of last modifying commission rate
     */
    struct NodeInfo {
        uint32 id;
        bool active;
        uint32 lastConfirmDate;
        uint8 commissionRate;
        address recipient;
        uint256 selfTotalRewards;
        uint256 selfClaimedRewards;
        uint256 delegationRewards;
        uint256 commissionRateLastModifyAt;
    }

    /**
     * @notice This struct represents the reward information of a license which is implemented by nft
     *
     * @custom:filed initialRewards When this license is delegated to a node, the initial amount of delegator's rewards needs to be recorded.
     * @custom:filed totalRewards The amount of rewards this license has been confirmed
     * @custom:filed claimedRewards The amount of rewards this license has been claimed
     */
    struct RewardInfo {
        uint256 initialRewards;
        uint256 totalRewards;
        uint256 claimedRewards;
    }

    // node
    /**
     * @notice Emitted when node modifies its commission rate
     * @param node The node address, which node's commission rate
     * @param commissionRate The new commission rate
     */
    event ModifyCommissionRate(address node, uint8 commissionRate);
    /**
     * @notice Emitted when account claims the node's rewards
     * @param node The node address
     * @param reward How many rewards
     */
    event NodeWithdraw(address node, uint256 reward);
    event ConfirmNodeReward(address node, uint256 selfTotalRewards, uint256 delegationRewards);
    event NodeDailyDelegations(address node, uint32 date, uint16 delegationAmount);
    event Delegate(uint256 tokenID, address to);
    event Undelegate(uint256 tokenID, address to);
    event Redelegate(uint256 tokenID, address to);
    event ClaimReward(address owner, uint256 tokenID, uint256 amount);
    event NodeRegister(address node, address recipient, uint8 commissionRate);

    function nodeRegister(
        uint8 commissionRate,
        address recipient,
        uint256[] calldata tokenIDs
    ) external;

    function delegate(uint256[] calldata tokenIDs, address to) external;

    function undelegate(uint256 tokenID) external;

    function redelegate(
        uint256 tokenID,
        address to
    ) external;

    function modifyCommissionRate(uint8 commissionRate) external;

    function nodeClaim() external;

    function delegationClaim(uint256 tokenID) external;

    function updateNodeDailyDelegations(address node) external;

    function confirmNodeReward(address node) external;

    function setMaxCommissionRate(uint8 value) external;

    function setCommissionRateModifyTimeLimit(uint32 value) external;

    function setMaxDelegationAmount(uint16 value) external;

    // --------------------------get--------------------------
    function licenseNFT() external view returns(address);
    function settlement() external view returns(address);
    function maxCommissionRate() external view returns(uint8);
    function commissionRateModifyTimeLimit() external view returns(uint32);
    function maxDelegationAmount() external view returns(uint16);
    function nodeIndex() external view returns(uint32);
    function getNodeInfo(address node) external view returns (NodeInfo memory);
    function delegationAmount(address node) external view returns (uint16);
    function delegation(uint256 tokenID) external view returns (address);
    function getRewardInfo(uint256 tokenID) external view returns (RewardInfo memory);
    function dailyDelegations(uint32 date) external view returns (uint32);
    function nodeDailyDelegations(address node, uint32 date) external view returns (uint32);
}