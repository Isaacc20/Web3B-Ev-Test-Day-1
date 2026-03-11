// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {EvictionVault} from "../src/EvictionVault.sol";

contract EvictionVaultScript is Script {
    EvictionVault public evictionVault;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address[] memory owners = new address[](3);
        owners[0] = vm.addr(1);
        owners[1] = vm.addr(2);
        owners[2] = vm.addr(3);

        evictionVault = new EvictionVault(owners, 2);

        vm.stopBroadcast();
    }
}
