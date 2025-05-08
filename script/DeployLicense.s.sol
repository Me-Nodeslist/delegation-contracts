// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
//import { Vm } from "forge-std/Vm.sol";
import {console2 as console} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

import "../src/LicenseNFT.sol";

contract Deploy is Script {
    /// @notice The deployed contract address will be written to this path.
    string internal deploymentOutfile;

    mapping(string => address) public deployments;
    ERC1967Proxy proxy;

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

        console.log("Writing contract address to %s", deploymentOutfile);
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
    }

    function deployERC1967Proxies() public {
        console.log("Deploying proxies");
        deployLicenseNFTProxy();
    }

    /// @notice Deploy the Credit
    function deployLicenseNFT() public broadcast {
        console.log("Deploying LicenseNFT");
        LicenseNFT licenseNFT = new LicenseNFT();
        console.log("LicenseNFT deployed at %s", address(licenseNFT));
        save("LicenseNFT", address(licenseNFT));
        deployments["LicenseNFT"] = address(licenseNFT);
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
