// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

interface IDelMemo {
    struct RedeemInfo {
        uint256 amount;
        uint256 claimAmount;
        uint256 unlockDate;
        address initiator;
        bool canceledOrClaimed;
    }

    event Mint(address depositer, address receiver, uint256 amount);
    event Redeem(
        uint256 redeemID,
        address initiator,
        uint256 amount,
        uint256 claimAmount,
        uint32 duration
    );
    event CancelRedeem(uint256 redeemID);
    event Claim(uint256 redeemID, uint256 amount);

    function redeem(uint256 amount, uint32 duration) external;
    function cancelRedeem(uint256 _redeemID) external;
    function claim(uint256 _redeemID) external;
    function mint(address receiver, uint256 amount) external;

    function setServiceFee(uint256 value) external;
    function setMemoToken(address _memoToken) external;
    function setFoundation(address _foundation) external;
    function setRedeemRules(
        uint32[] calldata durations,
        uint8[] calldata ratios
    ) external;

    //-----------------------get-------------------
    function serviceFee() external view returns (uint256);
    function memoToken() external view returns (address);
    function foundation() external view returns (address);
    function redeemIndex() external view returns (uint256);
    function redeemRules(uint32 duration) external view returns (uint8);
    function getRedeemInfo(uint256 redeemID) external view returns (RedeemInfo memory);
}
