// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {SoaringFund} from "../src/SoaringFund.sol";
import {TestToken} from "../src/TestToken.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract SoaringFundTest is Test {
    TestToken public testToken;
    SoaringFund public soaringFund;
    TransparentUpgradeableProxy public proxy;

    uint public constant INITIAL_SUPPLY = 10000000000;
    address public THIS_ADDRESS = address(this);
    address public routerAddress = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;
    address public rewardToken = 0x04756126F044634C9a0f0E985e60c88a51ACC206;  // CSIX
    address[] public path = [
        0x04756126F044634C9a0f0E985e60c88a51ACC206,  // CSIX
        0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82
    ];

    function setUp() public {
        testToken = new TestToken(INITIAL_SUPPLY);

        soaringFund = SoaringFund(address(new TransparentUpgradeableProxy(address(new SoaringFund()), THIS_ADDRESS, '')));
        soaringFund.initialize(address(testToken), routerAddress);

        soaringFund.setPath(rewardToken, path);
    }

    function test_stake() public {
        uint testStakeNum = 100e18;
        testToken.approve(address(soaringFund), testStakeNum);
        soaringFund.stake(testStakeNum);
        assertEq(soaringFund.totalStaked(), testStakeNum);
    }
}
