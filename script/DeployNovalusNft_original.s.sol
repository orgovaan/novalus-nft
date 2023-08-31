// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "../lib/forge-std/src/Script.sol";
import {NovalusNft} from "../src/NovalusNft_original.sol";

contract DeployNovalusNft is Script {
    function run() external returns (NovalusNft) {
        vm.startBroadcast();
        NovalusNft novalusNft = new NovalusNft("baseUri");
        vm.stopBroadcast();

        return (novalusNft);
    }
}
