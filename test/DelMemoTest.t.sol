// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/DelMEMO.sol";
import "./DelMEMO2.sol";
import "./MEMO.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DelMEMOTest is Test {
    DelMEMO delMemo;
    MEMO token;
    ERC1967Proxy proxy;
    address owner;
    address _implementation;

    string name = "DelMEMO";
    string symbol = "DelM";
    address memoToken;
    address foundation;
    uint256 serviceFee = 1e18;

    uint256 mintValue = 2e18;

    address tester = address(123);
    uint32[4] redeemDur = [uint32(5 days), 10 days, 60 days, 120 days];

    error OwnableUnauthorizedAccount(address account);
    error ERC20InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );

    function setUp() public {
        DelMEMO implementation = new DelMEMO();
        _implementation = address(implementation);
        owner = msg.sender;
        vm.prank(owner);
        token = new MEMO("MEMO", "M");
        memoToken = address(token);
        foundation = vm.addr(2);
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(
                implementation.initialize,
                (owner, name, symbol, memoToken, foundation, serviceFee)
            )
        );
        delMemo = DelMEMO(address(proxy));
        emit log_address(owner);
        emit log_address(memoToken);
        emit log_address(foundation);
    }

    function testInitialize() public {
        vm.prank(owner);
        assertEq(delMemo.memoToken(), memoToken);
        assertEq(delMemo.foundation(), foundation);
        assertEq(delMemo.redeemRules(10 days), 25);
        assertEq(delMemo.serviceFee(), 1e18);
    }

    function test_Mint_RevertWhen_CallerIsNotOwner() public {
        vm.prank(address(3));
        console.log("owner: %s, msg.sender: %s", owner, msg.sender);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUnauthorizedAccount.selector,
                address(3)
            )
        );
        delMemo.mint(address(2), mintValue);
    }

    function test_Mint_RevertWhenNotApprove() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20InsufficientAllowance.selector,
                address(delMemo),
                0,
                mintValue
            )
        );
        delMemo.mint(address(2), mintValue);
    }

    function testMint() public {
        vm.prank(owner);
        console.log("owner: %s, msg.sender: %s", owner, msg.sender);
        emit log_address(owner);
        emit log_address(msg.sender);

        token.approve(address(delMemo), mintValue);

        uint256 bal = token.balanceOf(owner);
        vm.prank(owner);
        delMemo.mint(tester, mintValue);
        uint256 balAfterMint = token.balanceOf(owner);
        assertEq(balAfterMint, bal - mintValue);

        uint256 delMemoBal = token.balanceOf(address(delMemo));
        assertEq(delMemoBal, mintValue);

        uint256 receiverBal = delMemo.balanceOf(tester);
        assertEq(receiverBal, mintValue);
    }

    function test_Redeem_Revert_When_InvalidDuration() public {
        vm.prank(owner);
        // mint
        token.approve(address(delMemo), mintValue);
        vm.prank(owner);
        delMemo.mint(tester, mintValue);
        uint256 receiverBal = delMemo.balanceOf(tester);
        assertEq(receiverBal, mintValue);
        // redeem 5 days, should revert
        console2.log(
            "owner: %s, msg.sender: %s, tester: %s",
            owner,
            msg.sender,
            tester
        );
        vm.prank(tester);
        vm.expectRevert("Invalid dur");
        delMemo.redeem(mintValue, redeemDur[0]);
    }

    function testRedeem() public {
        vm.prank(owner);
        // mint
        token.approve(address(delMemo), mintValue);
        vm.prank(owner);
        delMemo.mint(tester, mintValue);
        uint256 receiverBal = delMemo.balanceOf(tester);
        assertEq(receiverBal, mintValue);
        // redeem 10 days
        vm.prank(tester);
        delMemo.redeem(mintValue, redeemDur[1]);

        uint256 redeemIndex = delMemo.redeemIndex();
        assertEq(redeemIndex, 1);

        DelMEMO.RedeemInfo memory info = delMemo.getRedeemInfo(1);
        assertEq(info.amount, mintValue);
        assertEq(info.claimAmount, 25e16); // ((amount - serviceFee) * redeemRules[duration]) / 100

        receiverBal = delMemo.balanceOf(tester);
        assertEq(receiverBal, 0);

        uint256 contractBal = delMemo.balanceOf(address(delMemo));
        assertEq(contractBal, mintValue);
    }

    function testCancelRedeem_revert_when_not_initiator() public {
        vm.prank(owner);
        // mint
        token.approve(address(delMemo), mintValue);
        vm.prank(owner);
        delMemo.mint(tester, mintValue);
        uint256 receiverBal = delMemo.balanceOf(tester);
        assertEq(receiverBal, mintValue);
        // redeem 10 days
        vm.prank(tester);
        delMemo.redeem(mintValue, redeemDur[1]);
        // cancel redeem
        vm.prank(owner);
        vm.expectRevert("Err caller");
        delMemo.cancelRedeem(1);
    }

    function testCancelRedeem() public {
        vm.prank(owner);
        // mint
        token.approve(address(delMemo), mintValue);
        vm.prank(owner);
        delMemo.mint(tester, mintValue);
        uint256 receiverBal = delMemo.balanceOf(tester);
        assertEq(receiverBal, mintValue);
        // redeem 10 days
        vm.prank(tester);
        delMemo.redeem(mintValue, redeemDur[1]);
        // cancel redeem
        vm.prank(tester);
        delMemo.cancelRedeem(1);

        DelMEMO.RedeemInfo memory info = delMemo.getRedeemInfo(1);
        assertEq(info.canceledOrClaimed, true);

        receiverBal = delMemo.balanceOf(tester);
        assertEq(receiverBal, mintValue);

        uint256 contractBal = delMemo.balanceOf(address(delMemo));
        assertEq(contractBal, 0);
    }

    function testClaim() public {
        // mint
        vm.prank(owner);
        token.approve(address(delMemo), mintValue);
        vm.prank(owner);
        delMemo.mint(tester, mintValue);
        uint256 receiverBal = delMemo.balanceOf(tester);
        assertEq(receiverBal, mintValue);
        // redeem 10 days
        vm.prank(tester);
        delMemo.redeem(mintValue, redeemDur[1]);
        // claim
        vm.prank(tester);
        // time flies
        vm.warp(redeemDur[1] + 100);
        delMemo.claim(1);

        DelMEMO.RedeemInfo memory info = delMemo.getRedeemInfo(1);
        assertEq(info.canceledOrClaimed, true);
        assertEq(info.claimAmount, 25e16); // ((amount - serviceFee) * redeemRules[duration]) / 100

        receiverBal = token.balanceOf(tester);
        assertEq(receiverBal, info.claimAmount);

        uint256 foundationBal = token.balanceOf(foundation);
        assertEq(foundationBal, info.amount - info.claimAmount);

        uint256 contractBal = delMemo.balanceOf(address(delMemo));
        assertEq(contractBal, 0);
    }

    function testUpgradeability() public {
        ///vm.prank(owner);
        console2.log("owner: %s, msg.sender: %s", owner, msg.sender);
        emit log_address(owner);
        emit log_address(address(proxy));
        emit log_address(_implementation);
        Upgrades.upgradeProxy(
            address(proxy),
            "DelMEMO2.sol",
            abi.encodeCall(
                DelMEMO2.initialize,
                (owner, name, symbol, memoToken, foundation, serviceFee, 1)
            ),
            owner
        );
    }
}
