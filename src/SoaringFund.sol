// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPancakeRouter02} from "../src/interfaces/IPancakeRouter02.sol";
import {ISmartChefInitializable} from "src/interfaces/ISmartChefInitializable.sol";


contract SoaringFund is Ownable {

    event Swap(address indexed tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event Staked(address indexed user_, uint256 actualStakedAmount_, uint256 totalStakedNew);
    event Claimed(address indexed user_, uint256 actualClaimedAmount_, uint256 totalClaimedNew);
    event SetSmartChefArray(address[] smartChefArray_, uint256[] weightsArray_);
    event SetPath(address indexed token_, address[] swapPath_);
    event SetSwapRouter(address swapRouter_);

    address public stakeToken;
    uint256 public totalStaked;
    uint256 public totalClaimed;

    uint256 public totalFunds;  // redeem funds from mining pools
    uint256 public totalInvest;  // reinvest funds to mining pools
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public staked;
    mapping(address => uint256) public claimed;
    mapping(address => uint256) public userOwnRewardPerToken;

    uint256[] public weightsArray;
    address[] public smartChefArray;
    address public swapRouter;
    mapping(address => address[]) public swapPath;

    IERC20 cakeToken;
    ISmartChefInitializable smartChef;

    modifier renewPool(){
        _redeemFunds();
        _;
        _reinvest();
    }

    constructor(address stakeToken_, address swapRouter_) Ownable(msg.sender) { 
        stakeToken = stakeToken_;
        swapRouter = swapRouter_;
    }

    function stake(uint256 amount_) external {
        require(amount_ > 0, "Cannot stake 0");
        require(IERC20(stakeToken).balanceOf(msg.sender) >= amount_ , "Insufficient balance");

        uint balanceBefore = IERC20(stakeToken).balanceOf(address(this));
        IERC20(stakeToken).transferFrom(msg.sender, address(this), amount_);
        uint balanceAfter = IERC20(stakeToken).balanceOf(address(this));

        require(balanceAfter >= balanceBefore, "Token transfer overflow.");

        uint256 actualStakedAmount = balanceAfter - balanceBefore;
        staked[msg.sender] += actualStakedAmount;
        totalStaked += actualStakedAmount;
        emit Staked(msg.sender, amount_, totalStaked);
    }

    function claim(address user_) external renewPool returns (uint256) {
        uint256 actualClaimedAmount = _getReward(user_);
        require(actualClaimedAmount > 0, "No reward");
        totalInvest = totalFunds - actualClaimedAmount;
        return actualClaimedAmount;
    }

    function setSmartChefArray(
        address[] memory smartChefArray_,
        uint256[] memory weightsArray_
    ) external onlyOwner {
        require(weightsArray_.length == smartChefArray_.length, "Invalid array length");

        uint256 totalWeights;
        for (uint256 i = 0; i < weightsArray_.length; ++i) {
            require(smartChefArray_[i] != address(0), "Invalid address");
            totalWeights += weightsArray_[i];
        }
        require(totalWeights == 1e9, "Invalid weights");

        smartChefArray = smartChefArray_;
        weightsArray = weightsArray_;
        emit SetSmartChefArray(smartChefArray_, weightsArray_);
    }

    function setPath(address token_, address[] calldata swapPath_) external onlyOwner {
        swapPath[token_] = swapPath_;
        emit SetPath(token_, swapPath_);
    }

    function setSwapRouter(address swapRouter_) external onlyOwner {
        swapRouter = swapRouter_;
        emit SetSwapRouter(swapRouter_);
    }

    function _getRewardPerToken() internal view returns (uint256) {
        // (totalFunds - totalInvest) / totalStaked + rewardPerTokenStored
        if (totalStaked == 0 ) {
            return 0;
        }
        return (totalFunds - totalInvest) * 1e18 / totalStaked + rewardPerTokenStored;
    }

    function _updateRewardOf(address user_) internal view returns (uint256) {
        // (rewardPerToken - userOwnRewardPerToken[tokenId_]) * staked[tokenId_]
        uint256 newRewardPerToken_ = _getRewardPerToken();
        return (newRewardPerToken_ - userOwnRewardPerToken[user_]) * staked[user_] / 1e18;
    }

    function _updateUserRewardPerToken(address user_) internal {
        uint256 _rewardPerToken = _getRewardPerToken();
        rewardPerTokenStored = _rewardPerToken;
        userOwnRewardPerToken[user_] = _rewardPerToken;
    }

    function _claimInternal(address to_, uint256 amount_) internal returns (uint256) {
        uint balanceBefore = IERC20(stakeToken).balanceOf(address(this));
        IERC20(stakeToken).transfer(to_, amount_);
        uint balanceAfter = IERC20(stakeToken).balanceOf(address(this));
        require(balanceAfter <= balanceBefore, "Token transfer overflow.");
        uint256 actualClaimedAmount = balanceBefore - balanceAfter;

        uint256 totalClaimedNew = totalClaimed + actualClaimedAmount;
        require(totalClaimedNew > totalClaimed, "Total claimed overflow.");
        totalClaimed = totalClaimedNew;
        claimed[to_] += actualClaimedAmount;

        emit Claimed(to_, actualClaimedAmount, totalClaimedNew);
        return actualClaimedAmount;
    }

    function _redeemFunds() internal {
        if (totalInvest == 0 ) {
            // last invest funds is zero, no funds withdraw from smartChef.
            totalFunds = 0;
        } else {
            require(smartChefArray.length > 0, "No smartChefArray");
            uint256 prevBalance = cakeToken.balanceOf(address(this));
            
            for (uint256 i = 0; i < smartChefArray.length; ++i) {
                uint256 weight = weightsArray[i];
                smartChef = ISmartChefInitializable(smartChefArray[i]);
                address rewardToken = smartChef.rewardToken();

                if (weight > 0) {
                    (uint256 stakedAmount,) = smartChef.userInfo(address(this));  // fetch last staked amount
                    uint256 prevRewardBalance = IERC20(rewardToken).balanceOf(address(this));
                    smartChef.withdraw(stakedAmount);  // withdraw all cake and rewardToken.
                    uint256 afterRewardBalance = IERC20(rewardToken).balanceOf(address(this));

                    uint256 actualRewardBalance = afterRewardBalance - prevRewardBalance;
                    _swap(rewardToken, actualRewardBalance);
                }
            
            }

            uint256 afterBalance = cakeToken.balanceOf(address(this));
            totalFunds = afterBalance - prevBalance;
        }
        
    }

    function _reinvest() internal {
        require(smartChefArray.length > 0, "No smartChefArray");
        uint256 prevBalance = cakeToken.balanceOf(address(this));

        for (uint256 i = 0; i < smartChefArray.length; ++i) {
            uint256 weight = weightsArray[i];
            smartChef = ISmartChefInitializable(smartChefArray[i]);

            if (weight > 0) {
                uint256 investAmount = totalInvest * weight / 1e9;
                cakeToken.approve(smartChefArray[i], investAmount);
                smartChef.deposit(investAmount);
            }
        }

        uint256 afterBalance = cakeToken.balanceOf(address(this));
        totalInvest = prevBalance - afterBalance;  // actualInvestAmount
    }

    function _swap(address tokenIn, uint256 amountIn_) internal returns (uint256) {
        if (amountIn_ == 0) {
            return 0;
        }

        address[] memory path = swapPath[tokenIn];
        address tokenOut = path[path.length - 1];

        // Calculate the amount of exchange result.  [swapIn, swapOut]
        // uint256[] memory amounts = IPancakeRouter02(swapRouter).getAmountsOut(amountIn_, path);

        IERC20(tokenIn).approve(swapRouter, amountIn_);
        uint256[] memory SwapResult = IPancakeRouter02(swapRouter).swapExactTokensForTokens(
            amountIn_,  // the amount of input tokens.
            1,  // The minimum amount tokens to receive.
            path,  // An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity.
            address(this),  // Address of recipient.
            block.timestamp  // Unix timestamp deadline by which the transaction must confirm.
        );

        uint256 actualIn = SwapResult[0];
        uint256 actualOut = SwapResult[1];
        require(actualIn > 0 && actualOut > 0, "Swap failed");
        emit Swap(tokenIn, tokenOut, actualIn, actualOut);
        return actualOut;
    }

    function _getReward(address user_) internal returns (uint256) {
        uint256 actualUserClaimed;
        if (totalFunds > 0) {
            uint256 reward = _updateRewardOf(user_);
            _updateUserRewardPerToken(user_);
            
            if (reward > 0) {
                // uesr reward
                actualUserClaimed = _claimInternal(user_, reward);                
            }
        }

        return actualUserClaimed;
    }
}
