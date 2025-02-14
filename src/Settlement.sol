// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "./interfaces/ISettlement.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Settlement is ISettlement, Initializable, OwnableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    string public constant version = "0.1.0";

    bytes32 public constant DELEGATE_ROLE = keccak256("DELEGATE_ROLE");

    /// @notice The start time of delegation service 
    uint256 public startTime;

    /// @notice Delegation contract address
    address public delegation;
    /// @notice DelMemo contract address
    address public delMemo;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address _delegation, address _delMemo, uint256 _startTime) initializer public {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        delegation = _delegation;
        delMemo = _delMemo;
        _grantRole(DELEGATE_ROLE, delegation);
        startTime = _startTime;
    }

    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}

    function rewardWithdraw(address receiver, uint256 amount) external onlyRole(DELEGATE_ROLE) {
        IERC20(delMemo).transfer(receiver, amount);
        emit RewardWithdraw(receiver, amount);
    }

    function foundationWithdraw() external onlyOwner {
        uint256 bal = IERC20(delMemo).balanceOf(address(this));
        IERC20(delMemo).transfer(msg.sender, bal);
        emit FoundationWithdraw(msg.sender, bal);
    }

    function totalRewardDaily(uint32 date) public pure returns (uint256) {
        if(date <= 180) {
            return 154340e18;
        }else if(date <= 360) {
            return 115755e18;
        }else if (date <= 540) {
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