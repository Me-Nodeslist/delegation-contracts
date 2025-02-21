// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/DelMEMO.sol";
import "../src/Delegation.sol";
import "../src/interfaces/IDelegation.sol";
import "../src/LicenseNFT.sol";
import "../src/Settlement.sol";
import "./MEMO.sol";
import "./Delegation2.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DelegationTest is Test {
    MEMO token;
    address owner;

    DelMEMO delMemo;
    address _implementation_delMemo;

    Settlement settlement;
    address _implementation_settle;

    LicenseNFT licenseNFT;

    Delegation delegation;
    ERC1967Proxy proxy;
    address _implementation;

    string name = "DelMEMO";
    string symbol = "DelM";
    address memoToken;
    address foundation;
    uint256 serviceFee = 1e18;
    uint8 maxCommissionRate = 30;
    uint32 commissionRateModifyTimeLimit = 86400 * 3;
    uint16 maxDelegationAmount = 1000;

    uint256 startTime;

    uint256 mintValue = 2e23;
    address tester = address(123);
    address recipient = address(234);

    function setUp() public {
        owner = msg.sender;
        vm.startPrank(owner);

        token = new MEMO("MEMO", "M");
        memoToken = address(token);
        foundation = vm.addr(2);

        DelMEMO implementation_delMemo = new DelMEMO();
        _implementation_delMemo = address(implementation_delMemo);
        proxy = new ERC1967Proxy(
            address(implementation_delMemo),
            abi.encodeCall(
                implementation_delMemo.initialize,
                (owner, name, symbol, memoToken, foundation, serviceFee)
            )
        );
        delMemo = DelMEMO(address(proxy));

        Settlement implementation_settle = new Settlement();
        _implementation_settle = address(implementation_settle);
        startTime = block.timestamp;
        proxy = new ERC1967Proxy(
            address(implementation_settle),
            abi.encodeCall(
                implementation_settle.initialize,
                (owner, address(delMemo), startTime)
            )
        );
        settlement = Settlement(address(proxy));

        // deploy licenseNFT contract
        licenseNFT = new LicenseNFT();
        proxy = new ERC1967Proxy(
            address(licenseNFT),
            abi.encodeCall(
                licenseNFT.initialize,
                (owner, "License", "L", 100 days, 100 days, owner)
            )
        );
        licenseNFT = LicenseNFT(address(proxy));

        // deploy delegation contract
        Delegation implementation = new Delegation();
        _implementation = address(implementation);
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(
                implementation.initialize,
                (
                    owner,
                    address(licenseNFT),
                    address(settlement),
                    maxCommissionRate,
                    commissionRateModifyTimeLimit,
                    maxDelegationAmount
                )
            )
        );
        delegation = Delegation(address(proxy));

        // grantRole
        bytes32 role = settlement.DELEGATE_ROLE();
        //vm.prank(owner);
        settlement.grantRole(role, address(delegation));

        // transfer delMemo to settlement
        token.approve(address(delMemo), mintValue);
        uint256 bal = token.balanceOf(owner);
        delMemo.mint(address(settlement), mintValue);
        uint256 balAfterMint = token.balanceOf(owner);
        assertEq(balAfterMint, bal - mintValue);

        // grantRole
        role = delMemo.TRANSFER_ROLE();
        //vm.prank(owner);
        delMemo.grantRole(role, address(settlement));

        // mint license
        LicenseNFT.MetaData memory meta;
        licenseNFT.mint(owner, 2, meta);
        licenseNFT.mint(tester, 3, meta);

        console2.log("Owner address: ", owner);
        console2.log(
            "Has admin role(settlement)? ",
            settlement.hasRole(settlement.DEFAULT_ADMIN_ROLE(), owner)
        );
        console2.log(
            "Has admin role(delMemo)? ",
            delMemo.hasRole(delMemo.DEFAULT_ADMIN_ROLE(), owner)
        );
        console2.log("delMemo implementation: ", _implementation_delMemo);
        console2.log("settlement implementation: ", _implementation);
        console2.log("delegation implementation: ", _implementation);

        emit log_address(owner);
        emit log_address(address(delMemo));
        emit log_address(address(settlement));
        emit log_address(address(delegation));
        vm.stopPrank();
    }

    function testInitialize() public {
        vm.prank(owner);
        assertEq(settlement.startTime(), startTime);
        assertEq(settlement.delMemo(), address(delMemo));
        assertEq(
            settlement.hasRole(settlement.DEFAULT_ADMIN_ROLE(), owner),
            true
        );
        assertEq(delMemo.hasRole(delMemo.DEFAULT_ADMIN_ROLE(), owner), true);
        assertEq(delegation.licenseNFT(), address(licenseNFT));
        assertEq(delegation.settlement(), address(settlement));
        assertEq(delegation.maxCommissionRate(), maxCommissionRate);
        assertEq(delegation.commissionRateModifyTimeLimit(), commissionRateModifyTimeLimit);
        assertEq(delegation.maxDelegationAmount(), maxDelegationAmount);
    }

    function testNodeRegister_NoLicense() public {
        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit IDelegation.NodeRegister(owner, recipient, maxCommissionRate-10);

        uint256[] memory m;
        delegation.nodeRegister(maxCommissionRate-10, recipient, m);

        Delegation.NodeInfo memory info = delegation.getNodeInfo(owner);
        assertEq(info.active, false);
        assertEq(info.id, 1);
        assertEq(info.lastConfirmDate, 0);
        assertEq(info.commissionRate, maxCommissionRate-10);
        assertEq(info.recipient, recipient);
        assertEq(info.selfTotalRewards, 0);
        assertEq(info.selfClaimedRewards, 0);
        assertEq(info.delegationRewards, 0);
        assertEq(info.commissionRateLastModifyAt, vm.getBlockTimestamp());
    }

    function testNodeRegister() public {
        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit IDelegation.NodeRegister(owner, recipient, maxCommissionRate-10);

        uint256[] memory m = new uint256[](2);
        m[0] = 1;
        m[1] = 2;
        delegation.nodeRegister(maxCommissionRate-10, recipient, m);

        Delegation.NodeInfo memory info = delegation.getNodeInfo(owner);
        assertEq(info.active, true);
        assertEq(info.id, 1);
        assertEq(info.lastConfirmDate, 0);
        assertEq(info.commissionRate, maxCommissionRate-10);
        assertEq(info.recipient, recipient);
        assertEq(info.selfTotalRewards, 0);
        assertEq(info.selfClaimedRewards, 0);
        assertEq(info.delegationRewards, 0);
        assertEq(info.commissionRateLastModifyAt, vm.getBlockTimestamp());

        address to = delegation.delegation(1);
        assertEq(to, owner);
        to = delegation.delegation(2);
        assertEq(to, owner);

        uint16 amount = delegation.delegationAmount(owner);
        assertEq(amount, 2);

        Delegation.RewardInfo memory rewardInfo = delegation.getRewardInfo(1);
        assertEq(rewardInfo.initialRewards, 0);

        rewardInfo = delegation.getRewardInfo(2);
        assertEq(rewardInfo.initialRewards, 0);
    }

    function testDelegate_before_updateNodeDailyDelegations() public {
        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit IDelegation.NodeRegister(owner, recipient, maxCommissionRate-10);

        uint256[] memory m = new uint256[](2);
        m[0] = 1;
        m[1] = 2;
        delegation.nodeRegister(maxCommissionRate-10, recipient, m);

        vm.stopPrank();

        vm.startPrank(tester);
        uint256[] memory n = new uint256[](3);
        n[0] = 3;
        n[1] = 4;
        n[2] = 5;
        delegation.delegate(n, owner);

        Delegation.NodeInfo memory info = delegation.getNodeInfo(owner);
        assertEq(info.active, true);
        assertEq(info.id, 1);
        assertEq(info.lastConfirmDate, 0);
        assertEq(info.commissionRate, maxCommissionRate-10);
        assertEq(info.recipient, recipient);
        assertEq(info.selfTotalRewards, 0);
        assertEq(info.selfClaimedRewards, 0);
        assertEq(info.delegationRewards, 0);
        assertEq(info.commissionRateLastModifyAt, vm.getBlockTimestamp());

        address to = delegation.delegation(3);
        assertEq(to, owner);
        to = delegation.delegation(5);
        assertEq(to, owner);

        uint16 amount = delegation.delegationAmount(owner);
        assertEq(amount, 5);

        Delegation.RewardInfo memory rewardInfo = delegation.getRewardInfo(3);
        assertEq(rewardInfo.initialRewards, 0);

        rewardInfo = delegation.getRewardInfo(5);
        assertEq(rewardInfo.initialRewards, 0);
    }

    function testDelegate_after_updateNodeDailyDelegations() public {
        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit IDelegation.NodeRegister(owner, recipient, maxCommissionRate-10);

        uint256[] memory m = new uint256[](2);
        m[0] = 1;
        m[1] = 2;
        delegation.nodeRegister(maxCommissionRate-10, recipient, m);

        delegation.updateNodeDailyDelegations(owner);

        console2.log("current time: ", vm.getBlockTimestamp());
        uint32 today = uint32((vm.getBlockTimestamp() - startTime) / (1 days)) + 1;
        console2.log("today index: ", today);
        uint32 nodeDailyDelegation = delegation.nodeDailyDelegations(owner, today);
        assertEq(nodeDailyDelegation, 2);

        uint32 dailyDelegation = delegation.dailyDelegations(today);
        assertEq(dailyDelegation, 2);

        vm.warp(1 days + 1);
        console2.log("current time: ", vm.getBlockTimestamp());
        delegation.updateNodeDailyDelegations(owner);
        today = uint32((vm.getBlockTimestamp() - startTime) / (1 days)) + 1;
        console2.log("today index: ", today);

        vm.stopPrank();

        vm.startPrank(tester);
        uint256[] memory n = new uint256[](3);
        n[0] = 3;
        n[1] = 4;
        n[2] = 5;
        delegation.delegate(n, owner);

        nodeDailyDelegation = delegation.nodeDailyDelegations(owner, today);
        assertEq(nodeDailyDelegation, 5);

        dailyDelegation = delegation.dailyDelegations(today);
        assertEq(dailyDelegation, 5);

        Delegation.NodeInfo memory info = delegation.getNodeInfo(owner);
        assertEq(info.active, true);
        assertEq(info.lastConfirmDate, 1);
        assertEq(info.selfTotalRewards, 30868e18);
        assertEq(info.selfClaimedRewards, 0);
        assertEq(info.delegationRewards, 61736e18);

        Delegation.RewardInfo memory rewardInfo = delegation.getRewardInfo(3);
        assertEq(rewardInfo.initialRewards, 61736e18);

        rewardInfo = delegation.getRewardInfo(5);
        assertEq(rewardInfo.initialRewards, 61736e18);
    }

    function testUndelegate() public {
        vm.startPrank(owner);

        uint256[] memory m = new uint256[](2);
        m[0] = 1;
        m[1] = 2;
        delegation.nodeRegister(maxCommissionRate-10, recipient, m);

        vm.stopPrank();

        vm.startPrank(tester);
        uint256[] memory n = new uint256[](3);
        n[0] = 3;
        n[1] = 4;
        n[2] = 5;
        delegation.delegate(n, owner);

        delegation.updateNodeDailyDelegations(owner);

        vm.warp(1 days + 1);
        uint32 today = uint32((vm.getBlockTimestamp() - startTime) / (1 days)) + 1;

        delegation.updateNodeDailyDelegations(owner);

        Delegation.NodeInfo memory info = delegation.getNodeInfo(owner);
        assertEq(info.active, true);
        assertEq(info.lastConfirmDate, 0);
        assertEq(info.selfTotalRewards, 0);
        assertEq(info.selfClaimedRewards, 0);
        assertEq(info.delegationRewards, 0);

        delegation.undelegate(3);

        info = delegation.getNodeInfo(owner);
        assertEq(info.active, true);
        assertEq(info.lastConfirmDate, 1);
        assertEq(info.selfTotalRewards, 30868e18);
        assertEq(info.selfClaimedRewards, 0);
        assertEq(info.delegationRewards, 24690e18);

        uint32 nodeDailyDelegation = delegation.nodeDailyDelegations(owner, today);
        assertEq(nodeDailyDelegation, 4);

        uint32 dailyDelegation = delegation.dailyDelegations(today);
        assertEq(dailyDelegation, 4);

        address to = delegation.delegation(3);
        assertEq(to, address(0));

        uint16 amount = delegation.delegationAmount(owner);
        assertEq(amount, 4);

        Delegation.RewardInfo memory rewardInfo = delegation.getRewardInfo(3);
        assertEq(rewardInfo.initialRewards, 0);
        assertEq(rewardInfo.totalRewards, 24690e18);
    }

    function testNodeClaim() public {
        vm.startPrank(owner);

        uint256[] memory m = new uint256[](2);
        m[0] = 1;
        m[1] = 2;
        delegation.nodeRegister(maxCommissionRate - 10, recipient, m);

        delegation.updateNodeDailyDelegations(owner);

        vm.warp(1 days + 1);
        delegation.updateNodeDailyDelegations(owner);

        vm.stopPrank();

        vm.startPrank(tester);
        uint256[] memory n = new uint256[](3);
        n[0] = 3;
        n[1] = 4;
        n[2] = 5;
        delegation.delegate(n, owner);

        vm.stopPrank();

        vm.startPrank(owner);
        Delegation.NodeInfo memory info = delegation.getNodeInfo(owner);
        assertEq(info.lastConfirmDate, 1);
        assertEq(info.selfTotalRewards, 30868e18);
        assertEq(info.selfClaimedRewards, 0);
        assertEq(info.delegationRewards, 61736e18);
        uint256 bal = delMemo.balanceOf(address(settlement));
        assertEq(bal, mintValue);
        bal = delMemo.balanceOf(info.recipient);
        assertEq(bal, 0);

        delegation.nodeClaim();

        info = delegation.getNodeInfo(owner);
        assertEq(info.active, true);
        assertEq(info.lastConfirmDate, 1);
        assertEq(info.selfTotalRewards, 30868e18);
        assertEq(info.selfClaimedRewards, 30868e18);
        assertEq(info.delegationRewards, 61736e18);

        bal = delMemo.balanceOf(address(settlement));
        assertEq(bal, mintValue - 30868e18);
        bal = delMemo.balanceOf(info.recipient);
        assertEq(bal, 30868e18);
    }

    function testDelegationClaim() public {
        vm.startPrank(owner);

        uint256[] memory m = new uint256[](2);
        m[0] = 1;
        m[1] = 2;
        delegation.nodeRegister(maxCommissionRate - 10, recipient, m);

        delegation.updateNodeDailyDelegations(owner);

        vm.stopPrank();

        vm.startPrank(tester);
        uint256[] memory n = new uint256[](3);
        n[0] = 3;
        n[1] = 4;
        n[2] = 5;
        delegation.delegate(n, owner);

        vm.warp(1 days + 1);
        delegation.updateNodeDailyDelegations(owner);

        Delegation.RewardInfo memory rewardInfo = delegation.getRewardInfo(3);
        assertEq(rewardInfo.initialRewards, 0);
        assertEq(rewardInfo.totalRewards, 0);
        assertEq(rewardInfo.claimedRewards, 0);

        uint256 bal = delMemo.balanceOf(address(settlement));
        assertEq(bal, mintValue);
        bal = delMemo.balanceOf(tester);
        assertEq(bal, 0);

        delegation.delegationClaim(3);

        rewardInfo = delegation.getRewardInfo(3);
        assertEq(rewardInfo.initialRewards, 246944e17);
        assertEq(rewardInfo.totalRewards, 246944e17);
        assertEq(rewardInfo.claimedRewards, 246944e17);

        bal = delMemo.balanceOf(address(settlement));
        assertEq(bal, mintValue - 246944e17);
        bal = delMemo.balanceOf(tester);
        assertEq(bal, 246944e17);
    }

    function testUpgradeability() public {
        ///vm.prank(owner);
        console2.log("owner: %s, msg.sender: %s", owner, msg.sender);
        emit log_address(owner);
        emit log_address(address(delegation));
        emit log_address(_implementation);
        Upgrades.upgradeProxy(
            address(proxy),
            "Delegation2.sol",
            abi.encodeCall(
                Delegation2.initialize,
                (owner, address(licenseNFT), address(settlement))
            ),
            owner
        );
    }
}
