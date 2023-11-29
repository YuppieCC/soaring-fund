// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {TestToken} from "src/TestToken.sol";


contract TestTokenScript is Script {
    TestToken testToken;

    uint public constant INITIAL_SUPPLY = 10000000000;

    function run() public {
        vm.startBroadcast();
        testToken = new TestToken(INITIAL_SUPPLY);
        vm.stopBroadcast();
    }
}
