// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/DelMEMO.sol";
import "../src/Delegation.sol";
import "../src/LicenseNFT.sol";
import "../src/Settlement.sol";
import "./MEMO.sol";
import "./Settlement2.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract SettlementTest is Test {
    DelMEMO delMemo;
    address _implementation_delMemo;
    MEMO token;

    address owner;

    ERC1967Proxy proxy;
    address _implementation;
    Settlement settlement;

    string name = "DelMEMO";
    string symbol = "DelM";
    address memoToken;
    address foundation;
    uint256 serviceFee = 1e18;

    uint256 startTime; 

    uint256 mintValue = 2e18;
    address tester = address(123);

    function setUp() public {
        DelMEMO implementation = new DelMEMO();
        _implementation_delMemo = address(implementation);
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

        Settlement implementation_settle = new Settlement();
        _implementation = address(implementation_settle);
        startTime = block.timestamp + 3 days;
        proxy = new ERC1967Proxy(address(implementation_settle), abi.encodeCall(implementation_settle.initialize, (owner, address(delMemo), startTime)));
        settlement = Settlement(address(proxy));

        console2.log("Owner address: ", owner);
        console2.log("Has admin role(settlement)? ", settlement.hasRole(settlement.DEFAULT_ADMIN_ROLE(), owner));
        console2.log("Has admin role(delMemo)? ", delMemo.hasRole(delMemo.DEFAULT_ADMIN_ROLE(), owner));
        console2.log("delMemo implementation: ", _implementation_delMemo);
        console2.log("settlement implementation: ", _implementation);

        emit log_address(owner);
        emit log_address(address(delMemo));
        emit log_address(address(settlement));
    }

    function testInitialize() public {
        vm.prank(owner);
        assertEq(settlement.startTime(), startTime);
        assertEq(settlement.delMemo(), address(delMemo));
        assertEq(settlement.hasRole(settlement.DEFAULT_ADMIN_ROLE(), owner), true);
        assertEq(delMemo.hasRole(delMemo.DEFAULT_ADMIN_ROLE(), owner), true);
    }

    function testGrantRole() public {
        // deploy licenseNFT contract
        LicenseNFT licenseNFT = new LicenseNFT();
        proxy = new ERC1967Proxy(address(licenseNFT), abi.encodeCall(licenseNFT.initialize, (owner, "License", "L", 100 days, 100 days, owner)));
        licenseNFT = LicenseNFT(address(proxy));

        // deploy delegation contract
        Delegation delegation = new Delegation();
        proxy = new ERC1967Proxy(address(delegation), abi.encodeCall(delegation.initialize, (owner, address(licenseNFT), address(settlement), 30, 86400*3, 1000)));
        delegation = Delegation(address(proxy));

        // grantRole
        bytes32 role = settlement.DELEGATE_ROLE();
        vm.prank(owner);
        settlement.grantRole(role, address(delegation));
    }

    function testRewardWithdraw() public {
        // deploy licenseNFT contract
        vm.startPrank(owner);
        LicenseNFT licenseNFT = new LicenseNFT();
        proxy = new ERC1967Proxy(address(licenseNFT), abi.encodeCall(licenseNFT.initialize, (owner, "License", "L", 100 days, 100 days, owner)));
        licenseNFT = LicenseNFT(address(proxy));

        // deploy delegation contract
        Delegation delegation = new Delegation();
        proxy = new ERC1967Proxy(address(delegation), abi.encodeCall(delegation.initialize, (owner, address(licenseNFT), address(settlement), 30, 86400*3, 1000)));
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

        // granRole
        role = delMemo.TRANSFER_ROLE();
        //vm.prank(owner);
        delMemo.grantRole(role, address(settlement));

        // test rewardWithdraw()
        vm.stopPrank();
        vm.prank(address(delegation));
        settlement.rewardWithdraw(tester, mintValue);
        uint256 delMemoBalance = delMemo.balanceOf(tester);
        assertEq(delMemoBalance, mintValue);
    }

    function testFoundationWithdraw() public {
        vm.startPrank(owner);
        // transfer delMemo to settlement
        token.approve(address(delMemo), mintValue);
        uint256 bal = token.balanceOf(owner);
        //vm.prank(owner);
        delMemo.mint(address(settlement), mintValue);
        uint256 balAfterMint = token.balanceOf(owner);
        assertEq(balAfterMint, bal - mintValue);
        assertEq(delMemo.balanceOf(address(settlement)), mintValue);

        console2.log("msg.sender: %s", msg.sender);
        console2.log("delMemo: %s", address(delMemo));
        console2.log("settlement: %s", address(settlement));
        // granRole
        emit log_address(msg.sender);
        emit log_address(owner);
        bytes32 role = delMemo.TRANSFER_ROLE();
        //vm.prank(owner);
        delMemo.grantRole(role, address(settlement));

        // test foundationWithdraw()
        //vm.prank(owner);
        settlement.foundationWithdraw();
        uint256 delMemoBalance = delMemo.balanceOf(foundation);
        assertEq(delMemoBalance, mintValue);
    }

    function testUpgradeability() public {
        ///vm.prank(owner);
        console2.log("owner: %s, msg.sender: %s", owner, msg.sender);
        emit log_address(owner);
        emit log_address(address(settlement));
        emit log_address(_implementation);
        Upgrades.upgradeProxy(
            address(proxy),
            "Settlement2.sol",
            abi.encodeCall(
                Settlement2.initialize,
                (owner, address(delMemo), startTime)
            ),
            owner
        );
    }
}
