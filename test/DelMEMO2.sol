// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "../src/interfaces/IDelMemo.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:oz-upgrades-from DelMEMO
contract DelMEMO2 is
    IDelMemo,
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    string public constant version = "0.1.1";

    uint256 public serviceFee;

    address public memoToken;
    address public foundation;

    /// @notice Current redeem index. Every time an account redeems reward, the redeemIndex will increase by 1
    uint256 public redeemIndex;
    /// @notice Redeem index -> redeem information
    mapping(uint256 => RedeemInfo) redeemInfos;
    /// @notice Record the percentage that can be redeemed during different lock-up period
    mapping(uint32 => uint8) public redeemRules;

    uint256 tmp;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        string memory name,
        string memory symbol,
        address _memoToken,
        address _foundation,
        uint256 _serviceFee,
        uint256 _tmp
    ) public reinitializer(2) {
        __ERC20_init(name, symbol);
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        memoToken = _memoToken;
        foundation = _foundation;

        serviceFee = _serviceFee;
        tmp = _tmp;

        redeemRules[10 days] = 25;
        redeemRules[60 days] = 60;
        redeemRules[120 days] = 100;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
     * @notice Mint delMEMO tokens to receiver
     * @param receiver Receive the mined delMEMO tokens
     * @param amount Number of delMEMO tokens mined 
     */
    function mint(address receiver, uint256 amount) external onlyOwner {
        _mint(receiver, amount+tmp);
        emit Mint(msg.sender, receiver, amount);
    }

    /**
     * @notice Account deposit delMEMO tokens, and then can claim MEMO tokens after the lock-in period
     * @param amount Number of delMEMO tokens staked
     * @param duration Lock-in period for staked tokens
     */
    function redeem(uint256 amount, uint32 duration) external {
        require(amount > serviceFee, "Less than 1token");
        require(redeemRules[duration] != 0, "Invalid dur");
        _transfer(msg.sender, address(this), amount);

        uint256 claimAmount = ((amount - serviceFee) * redeemRules[duration]) /
            100;

        redeemIndex++;
        redeemInfos[redeemIndex] = RedeemInfo(
            amount,
            claimAmount,
            block.timestamp + duration,
            msg.sender,
            false
        );

        emit Redeem(redeemIndex, msg.sender, amount, claimAmount, duration);
    }

    function cancelRedeem(uint256 _redeemID) external {
        RedeemInfo storage redeemInfo = redeemInfos[_redeemID];

        require(redeemInfo.initiator == msg.sender, "Err caller");
        require(!redeemInfo.canceledOrClaimed, "Canceled or claimed");

        redeemInfo.canceledOrClaimed = true;
        _transfer(address(this), msg.sender, redeemInfo.amount);

        emit CancelRedeem(_redeemID);
    }

    /**
     * @notice Account claim MEMO tokens after redeem
     * @param _redeemID The id of redeem
     */
    function claim(uint256 _redeemID) external {
        RedeemInfo storage redeemInfo = redeemInfos[_redeemID];

        require(redeemInfo.initiator == msg.sender, "Err caller");
        require(!redeemInfo.canceledOrClaimed, "Canceled or claimed");
        require(redeemInfo.unlockDate < block.timestamp, "Lock");

        redeemInfo.canceledOrClaimed = true;
        _burn(address(this), redeemInfo.amount);
        IERC20(memoToken).transfer(msg.sender, redeemInfo.claimAmount);
        IERC20(memoToken).transfer(
            foundation,
            redeemInfo.amount - redeemInfo.claimAmount
        );

        emit Claim(_redeemID, redeemInfo.claimAmount);
    }

    function transfer(
        address to,
        uint256 value
    ) public override onlyOwner returns (bool) {
        return super.transfer(to, value);
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override onlyOwner returns (bool) {
        return super.transferFrom(from, to, value);
    }

    function setServiceFee(uint256 value) external onlyOwner {
        serviceFee = value;
    }

    function setMemoToken(address _memoToken) external onlyOwner {
        memoToken = _memoToken;
    }

    function setFoundation(address _foundation) external onlyOwner {
        foundation = _foundation;
    }

    function setRedeemRules(
        uint32[] calldata durations,
        uint8[] calldata ratios
    ) external onlyOwner {
        for (uint8 i = 0; i < durations.length; i++) {
            redeemRules[durations[i]] = redeemRules[ratios[i]];
        }
    }

    //--------------------get---------------
    function getRedeemInfo(uint256 redeemID) external view returns (RedeemInfo memory) {
        return redeemInfos[redeemID];
    }
}
