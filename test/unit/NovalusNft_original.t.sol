//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DeployNovalusNft} from "../../script/DeployNovalusNft_original.s.sol";
import {NovalusNft} from "../../src/NovalusNft_original.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";

contract NovalusNftTest is Test {
    /* Events */
    //events are not types like enums and structs, so we cannot import them, we have to add them here as well
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);

    NovalusNft novalusNft;

    address public USER = makeAddr("user");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployNovalusNft deployer = new DeployNovalusNft();
        novalusNft = deployer.run();

        vm.deal(USER, STARTING_USER_BALANCE); //give the USER some money
    }
}
