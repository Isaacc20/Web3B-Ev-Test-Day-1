// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {Execution} from "../src/core/Execution.sol";
import {GovernanceToken} from "../src/modules/GovernanceToken.sol";

contract ExecutionScript is Script {
    Execution public execution;
    GovernanceToken public token;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(1));
        vm.startBroadcast(deployerPrivateKey);

        token = new GovernanceToken();

        address[] memory owners = new address[](3);
        owners[0] = vm.addr(1);
        owners[1] = vm.addr(2);
        owners[2] = vm.addr(3);

        execution = new Execution(address(token), owners, 2);

        vm.stopBroadcast();
    }
}
