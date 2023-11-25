// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SoaringFund is Ownable {

    event Staked(address indexed user_, uint256 actualStakedAmount_, uint256 totalStakedNew);
    event Claimed(address indexed user_, uint256 actualClaimedAmount_, uint256 totalClaimedNew);

    address public stakeToken;
    uint256 public totalStaked;
    uint256 public totalClaimed;

    constructor(address stakeToken_) Ownable(msg.sender) { 
        stakeToken = stakeToken_;
    }

    function stake(uint256 amount_) external {
        require(amount_ > 0, "Cannot stake 0");
        require(IERC20(stakeToken).balanceOf(msg.sender) >= amount_ , "Insufficient balance");

        uint balanceBefore = IERC20(stakeToken).balanceOf(address(this));
        IERC20(stakeToken).transferFrom(msg.sender, address(this), amount_);
        uint balanceAfter = IERC20(stakeToken).balanceOf(address(this));

        require(balanceAfter >= balanceBefore, "Token transfer overflow.");

        uint256 actualStakedAmount = balanceAfter - balanceBefore;
        totalStaked += actualStakedAmount;
        emit Staked(msg.sender, amount_, totalStaked);
    }

    function claimed(uint256 amount_) external {
        require(amount_ > 0, "Cannot claim 0");
        require(IERC20(stakeToken).balanceOf(address(this)) >= amount_ , "Insufficient balance to claim");

        uint balanceBefore = IERC20(stakeToken).balanceOf(address(this));
        IERC20(stakeToken).transfer(msg.sender, amount_);
        uint balanceAfter = IERC20(stakeToken).balanceOf(address(this));

        require(balanceAfter <= balanceBefore, "Token transfer overflow.");

        uint256 actualClaimedAmount = balanceBefore - balanceAfter;
        totalClaimed += totalClaimed;
        emit Claimed(msg.sender, actualClaimedAmount, totalClaimed);
    }
    
}