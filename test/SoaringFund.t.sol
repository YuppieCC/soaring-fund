// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {SoaringFund} from "../src/SoaringFund.sol";
import {TestToken} from "../src/TestToken.sol";

contract SoaringFundTest is Test {
    TestToken public testToken;
    SoaringFund public soaringFund;

    uint public constant INITIAL_SUPPLY = 10000000000;
    address public THIS_ADDRESS = address(this);
    address public routerAddress = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;

    function setUp() public {
        testToken = new TestToken(INITIAL_SUPPLY);
        soaringFund = new SoaringFund(address(testToken), routerAddress);
    }

    function test_stake() public {
        uint testStakeNum = 100e18;
        testToken.approve(address(soaringFund), testStakeNum);
        soaringFund.stake(testStakeNum);
        assertEq(soaringFund.totalStaked(), testStakeNum);
    }
}
