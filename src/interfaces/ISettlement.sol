// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

interface ISettlement {
    event RewardWithdraw(address receiver, uint256 amount);
    event FoundationWithdraw(address foundation, uint256 amount);

    function rewardWithdraw(address receiver, uint256 amount) external;
    function foundationWithdraw() external;
    
    function startTime() external view returns (uint256);
    function totalRewardDaily(uint32 date) external returns (uint256);
}