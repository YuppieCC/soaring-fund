// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SoaringFund} from "../src/SoaringFund.sol";


contract SoaringFund_BSCTest is Test {
    SoaringFund public soaringFund;

    uint public constant INITIAL_SUPPLY = 10000000000;
    address public THIS_ADDRESS = address(this);
    address public CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address public CAKE_HOLDER = 0x776FcD96b8F671A40b339341D85ef9c4035a3045;
    address public routerAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    uint256[] public weightsArray_ = [1e9];
    address[] public smartChefArray_ = [0x692dF8297495f02f31a24A93D10Bd77D072840d7];
    address public rewardToken = 0x04756126F044634C9a0f0E985e60c88a51ACC206;  // CSIX
    address[] public path = [
        0x04756126F044634C9a0f0E985e60c88a51ACC206,  // CSIX
        0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82
    ];

    function setUp() public {
        soaringFund = new SoaringFund(CAKE, routerAddress);
        soaringFund.setPath(rewardToken, path);
        soaringFund.setSmartChefArray(smartChefArray_, weightsArray_);
        vm.warp(block.timestamp + 10000);
        vm.roll(block.number + 1000);
    }

    function test_stake() public {
        vm.startPrank(CAKE_HOLDER);
        uint testStakeNum = 100e18;
        IERC20(CAKE).approve(address(soaringFund), testStakeNum);
        soaringFund.stake(testStakeNum);
        assertEq(soaringFund.totalStaked(), testStakeNum);
        vm.stopPrank();
    }

    function test_updatePool() public {
        vm.startPrank(CAKE_HOLDER);
        uint testStakeNum = 100e18;
        IERC20(CAKE).approve(address(soaringFund), testStakeNum);

        assertTrue(soaringFund.totalFunds() == 0);
        assertTrue(soaringFund.totalInvest() == 0);
        soaringFund.stake(testStakeNum);
        assertTrue(soaringFund.totalFunds() == 0);
        assertTrue(soaringFund.totalInvest() > 0);

        vm.warp(block.timestamp + 10000);
        vm.roll(block.number + 1000);

        soaringFund.updatePool();
        assertTrue(soaringFund.totalFunds() > 0);
        assertTrue(soaringFund.totalFunds() == soaringFund.totalInvest());

        vm.stopPrank();
    }

    function test_claim() public {
        vm.startPrank(CAKE_HOLDER);
        uint testStakeNum = 100e18;
        IERC20(CAKE).approve(address(soaringFund), testStakeNum);
        soaringFund.stake(testStakeNum);

        vm.warp(block.timestamp + 10000);
        vm.roll(block.number + 1000);

        soaringFund.updatePool();

        vm.warp(block.timestamp + 50000);
        vm.roll(block.number + 5000);

        uint256 beforeClaimBalance = IERC20(CAKE).balanceOf(CAKE_HOLDER);        
        soaringFund.claim();
        uint256 afterClaimBalance = IERC20(CAKE).balanceOf(CAKE_HOLDER);
        assertTrue(afterClaimBalance > beforeClaimBalance);
        assertTrue(soaringFund.totalClaimed() > 0);
        vm.stopPrank();
    }
}
