// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
//import { Vm } from "forge-std/Vm.sol";
import {console2 as console} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

import "../src/Delegation.sol";
import "../src/DelMEMO2.sol";
import "../src/LicenseNFT.sol";
import "../src/Settlement.sol";

contract Deploy is Script {
    /// @notice The deployed contract address will be written to this path.
    string internal deploymentOutfile;

    mapping(string => address) public deployments;
    ERC1967Proxy proxy;

    address memoToken;
    uint256 startTime;
    uint8 maxCommissionRate;
    uint32 commissionRateModifyTimeLimit;
    uint16 maxDelegationAmount;

    uint256 mintValue;

    /// @notice Modifier that wraps a function in broadcasting.
    modifier broadcast() {
        vm.startBroadcast(msg.sender);
        _;
        vm.stopBroadcast();
    }

    /// @notice Setup function. The arguments here
    function setUp() public virtual {
        deploymentOutfile = vm.envOr(
            "DEPLOYMENT_OUTFILE",
            string.concat(vm.projectRoot(), "/script/deployment.json")
        );
        memoToken = vm.envAddress("MEMO_TOKEN");
        startTime = vm.envOr(
            "START_TIME",
            (block.timestamp / (1 days)) * (1 days)
        );
        maxCommissionRate = uint8(vm.envOr("MAX_COMMISSIONRATE", uint8(30))); // 30%
        commissionRateModifyTimeLimit = uint8(
            vm.envOr("COMMISSIONRATE_MODIFY_TIMELIMIT", uint32(259200))
        ); // 3 days
        maxDelegationAmount = uint8(
            vm.envOr("MAX_DELEGATION_AMOUNT", uint16(100))
        );
        mintValue = vm.envOr("MINT_VALUE", uint256(16e23)); // approximately 10 days of release, 1.6 million tokens

        console.log("Writing contract address to %s", deploymentOutfile);
        console.log("MemoToken address is %s", memoToken);
        console.log("StartTime is %d", startTime);
        console.log("MaxCommissionRate is %d", maxCommissionRate);
        console.log(
            "CommissionRateModifyTimeLimit is %d",
            commissionRateModifyTimeLimit
        );
        console.log("MaxDelegationAmount is %d", maxDelegationAmount);
    }

    function run() public {
        console.log("Deploying NodeDelegation contracts");

        deployImplementations();

        deployERC1967Proxies();
    }

    /// @notice Deploy all of the implementations
    function deployImplementations() public {
        console.log("Deploying implementations");
        deployLicenseNFT();
        deployDelMEMO();
        deploySettlement();
        deployDelegation();
    }

    function deployERC1967Proxies() public {
        console.log("Deploying proxies");
        address licenseNFTProxy = deployLicenseNFTProxy();
        address delMEMOProxy = deployDelMEMOProxy();
        address settlementProxy = deploySettlementProxy(delMEMOProxy);
        address delegationProxy = deployDelegationProxy(
            licenseNFTProxy,
            settlementProxy
        );
        grantRole(settlementProxy, delegationProxy, delMEMOProxy);
        mintDelMemo(settlementProxy, delMEMOProxy);
    }

    /// @notice Deploy the Credit
    function deployLicenseNFT() public broadcast {
        console.log("Deploying LicenseNFT");
        LicenseNFT licenseNFT = new LicenseNFT();
        console.log("LicenseNFT deployed at %s", address(licenseNFT));
        save("LicenseNFT", address(licenseNFT));
        deployments["LicenseNFT"] = address(licenseNFT);
    }

    function deployDelMEMO() public broadcast {
        console.log("Deploying DelMEMO");
        DelMEMO2 gtk = new DelMEMO2();
        console.log("DelMEMO deployed at %s", address(gtk));
        save("DelMEMO", address(gtk));
        deployments["DelMEMO"] = address(gtk);
    }

    function deploySettlement() public broadcast {
        console.log("Deploying Settlement");
        Settlement market = new Settlement();
        console.log("Settlement deployed at %s", address(market));
        save("Settlement", address(market));
        deployments["Settlement"] = address(market);
    }

    function deployDelegation() public broadcast {
        console.log("Deploying Delegation");
        Delegation pledge = new Delegation();
        console.log("Delegation deployed at %s", address(pledge));
        save("Delegation", address(pledge));
        deployments["Delegation"] = address(pledge);
    }

    function deployLicenseNFTProxy() public broadcast returns (address) {
        address licenseNFT = deployments["LicenseNFT"];
        proxy = new ERC1967Proxy(
            licenseNFT,
            abi.encodeCall(
                LicenseNFT(licenseNFT).initialize,
                (
                    msg.sender,
                    "MEMOLicense",
                    "ML",
                    block.timestamp + 180 days,
                    block.timestamp + 240 days,
                    address(0x98B0B2387f98206efbF6fbCe2462cE22916BAAa3)
                )
            )
        );
        console.log("LicenseNFTProxy deployed at %s", address(proxy));
        save("LicenseNFTProxy", address(proxy));
        return address(proxy);
    }

    function deployDelMEMOProxy() public broadcast returns (address) {
        address delmemo = deployments["DelMEMO"];
        proxy = new ERC1967Proxy(
            delmemo,
            abi.encodeCall(
                DelMEMO2(delmemo).initialize,
                (
                    msg.sender,
                    "DelMEMO",
                    "dmemo",
                    memoToken,
                    address(0x98B0B2387f98206efbF6fbCe2462cE22916BAAa3),
                    1e18
                )
            )
        );
        console.log("DelMEMOProxy deployed at %s", address(proxy));
        save("DelMEMOProxy", address(proxy));
        return address(proxy);
    }

    function deploySettlementProxy(
        address delMemo
    ) public broadcast returns (address) {
        address settlement = deployments["Settlement"];
        proxy = new ERC1967Proxy(
            settlement,
            abi.encodeCall(
                Settlement(settlement).initialize,
                (msg.sender, delMemo, startTime)
            )
        );
        console.log("SettlementProxy deployed at %s", address(proxy));
        save("SettlementProxy", address(proxy));
        return address(proxy);
    }

    function deployDelegationProxy(
        address licenseNFT,
        address settlement
    ) public broadcast returns (address) {
        address delegation = deployments["Delegation"];
        proxy = new ERC1967Proxy(
            delegation,
            abi.encodeCall(
                Delegation(delegation).initialize,
                (
                    msg.sender,
                    licenseNFT,
                    settlement,
                    maxCommissionRate,
                    commissionRateModifyTimeLimit,
                    maxDelegationAmount
                )
            )
        );
        console.log("DelegationProxy deployed at %s", address(proxy));
        save("DelegationProxy", address(proxy));
        return address(proxy);
    }

    function grantRole(
        address settlementProxy,
        address delegationProxy,
        address delMEMOProxy
    ) public broadcast {
        Settlement settlement = Settlement(settlementProxy);
        settlement.grantRole(settlement.DELEGATE_ROLE(), delegationProxy);
        console.log("Have grantted delegation-address DELEGATE_ROLE");

        DelMEMO2 delmemo = DelMEMO2(delMEMOProxy);
        delmemo.grantRole(delmemo.TRANSFER_ROLE(), settlementProxy);
        console.log("Have grantted settlement-address TRANSFER_ROLE");
    }

    function mintDelMemo(
        address settlementProxy,
        address delMEMOProxy
    ) public broadcast {
        uint256 bal = IERC20(memoToken).balanceOf(msg.sender);
        console.log("Deployer's balance: ", bal, " attomemo");
        require(
            bal >= mintValue,
            "Deployer's balance not enough, shouldn't be less than $MINT_VALUE"
        );

        IERC20(memoToken).approve(address(delMEMOProxy), mintValue);

        DelMEMO2(delMEMOProxy).mint(address(settlementProxy), mintValue);

        uint256 balAfterMint = IERC20(memoToken).balanceOf(msg.sender);
        console.log("Deployer's balance: ", balAfterMint, " attomemo");

        bal = DelMEMO2(delMEMOProxy).balanceOf(address(settlementProxy));
        console.log("Settlement-address's balance: ", bal, " attoDelMEMO");
    }

    /// @notice Appends a deployment to disk as a JSON deploy artifact.
    /// @param _name The name of the deployment.
    /// @param _deployed The address of the deployment.
    function save(string memory _name, address _deployed) public {
        console.log("Saving %s: %s", _name, _deployed);
        vm.writeJson({
            json: stdJson.serialize("", _name, _deployed),
            path: deploymentOutfile
        });
    }
}
