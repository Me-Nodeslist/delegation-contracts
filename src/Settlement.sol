// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "./interfaces/ISettlement.sol";
import "./interfaces/IDelMemo.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Settlement is
    ISettlement,
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    string public constant version = "0.1.0";

    bytes32 public constant DELEGATE_ROLE = keccak256("DELEGATE_ROLE");

    /// @notice The start time of delegation service
    uint256 public startTime;

    /// @notice DelMemo contract address
    address public delMemo;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        address _delMemo,
        uint256 _startTime
    ) public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        __UUPSUpgradeable_init();

        delMemo = _delMemo;
        startTime = _startTime;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @dev Called by 'Delegation' contract, should grant 'DELEGATE_ROLE' to 'Delegation' contract.
     * @param receiver Who receive the withdrawal reward
     * @param amount The number of reward
     */
    function rewardWithdraw(
        address receiver,
        uint256 amount
    ) external onlyRole(DELEGATE_ROLE) {
        IERC20(delMemo).transfer(receiver, amount);
        emit RewardWithdraw(receiver, amount);
    }

    function foundationWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 bal = IERC20(delMemo).balanceOf(address(this));
        IERC20(delMemo).transfer(IDelMemo(delMemo).foundation(), bal);
        emit FoundationWithdraw(msg.sender, bal);
    }

    /**
     * @dev 100 million tokens will be released over 4 years, with the release amount decreasing by 25% every 6 months.
     * @param date 4-year date index, from 1 to 1440
     */
    function totalRewardDaily(uint32 date) public pure returns (uint256) {
        if (date <= 180) {
            return 154340e18;
        } else if (date <= 360) {
            return 115755e18;
        } else if (date <= 540) {
            return 86816e18;
        } else if (date <= 720) {
            return 65112e18;
        } else if (date <= 900) {
            return 48834e18;
        } else if (date <= 1080) {
            return 36625e18;
        } else if (date <= 1260) {
            return 27469e18;
        } else if (date <= 1440) {
            return 20601e18;
        } else {
            return 0;
        }
    }
}
