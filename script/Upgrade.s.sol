// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console2 as console} from "forge-std/console2.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import "../src/DelMEMO2.sol";

contract Upgrade is Script {
    /// @notice The deployed contract address will be written to this path.
    string internal deploymentOutfile;

    mapping(string => address) public deployments;
    address delMEMOProxy;

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
        delMEMOProxy = vm.envAddress("DELMEMO_PROXY");

        console.log("Writing contract address to %s", deploymentOutfile);
    }

    function run() public broadcast {
        console.log("Upgrading DelMEMO contracts");

        Upgrades.upgradeProxy(
            address(delMEMOProxy),
            "DelMEMO2.sol",
            "",
            msg.sender
        );

        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        bytes32 implementationData = vm.load(delMEMOProxy, slot);
        address newImplementation = address(
            uint160(uint256(implementationData))
        );
        console.log("New implementation address is %s", newImplementation);
        save("DelMEMO2", newImplementation);
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
