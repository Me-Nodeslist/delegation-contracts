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
    uint32 commissionRateModifyTimeLimit = 86400*3;
    uint16 maxDelegationAmount = 1000;

    uint256 startTime;

    uint256 mintValue = 2e18;
    address tester = address(123);
    address recipient = address(234);

    function setUp() public {
        owner = msg.sender;

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
        proxy = new ERC1967Proxy(address(licenseNFT), abi.encodeCall(licenseNFT.initialize, (owner, "License", "L", 100 days, 100 days, owner)));
        licenseNFT = LicenseNFT(address(proxy));

        Delegation implementation = new Delegation();
        _implementation = address(implementation);
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(implementation.initialize, (owner, address(licenseNFT), address(settlement), maxCommissionRate, commissionRateModifyTimeLimit, maxDelegationAmount)));
        delegation = Delegation(address(proxy));

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
        uint256[] memory m;
        vm.expectEmit(true, true, true, true);
        emit IDelegation.NodeRegister(owner, recipient, maxCommissionRate-10);

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
