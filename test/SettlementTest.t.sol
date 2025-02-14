// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/DelMEMO.sol";
import "../src/Delegation.sol";
import "./MEMO.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract SettlementTest is Test {
    DelMEMO delMemo;
    Delegation delegation;
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

        Delegation implementation_Del = new Delegation();
        _implementation = address(implementation_Del);
        proxy = new ERC1967Proxy(address(implementation_Del), abi.encodeCall(implementation_Del.initialize, ))

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
