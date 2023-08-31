//deploy: forge script ./script/DeployNovalusNftController.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "../lib/forge-std/src/Script.sol";
import {NovalusNft} from "../src/NovalusNft.sol";
import {NovalusNftController} from "../src/NovalusNftController.sol";

contract DeployNovalusNftController is Script {
    address mockController = 0x7Cf2703e09EAE37cf1204Fa2d3A24E0bB03A8c93;
    string s_baseUri = "blablabla";

    function run() external returns (NovalusNftController) {
        vm.startBroadcast();
        NovalusNftController novalusNftController = new NovalusNftController(
            mockController,
            s_baseUri
        );
        vm.stopBroadcast();

        return (novalusNftController);
    }
}
