// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPancakeRouter02} from "src/interfaces/IPancakeRouter02.sol";
import {ISmartChefInitializable} from "src/interfaces/ISmartChefInitializable.sol";
import {TokenTransfer} from "src/utils/TokenTransfer.sol";
import {RoleControl} from "src/utils/RoleControl.sol";
import {ISoaringFund} from "src/interfaces/ISoaringFund.sol";

contract SoaringFund is ISoaringFund, RoleControl, TokenTransfer {

    event Swap(address indexed tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event Staked(address indexed user_, uint256 actualStakedAmount_, uint256 totalStakedNew);
    event Claimed(address indexed user_, uint256 actualClaimedAmount_, uint256 totalClaimedNew);
    event ExitFunds(address indexed user_, uint256 actualExitAmount_, uint256 totalStakedNew);
    event SetSmartChefArray(address[] smartChefArray_, uint256[] weightsArray_);
    event SetPath(address indexed token_, address[] swapPath_);
    event SetSwapRouter(address swapRouter_);

    IERC20 cakeToken;
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

    ISmartChefInitializable smartChef;

    modifier renewPool(){
        _redeemFunds();
        _;
        _reinvest();
    }

    function initialize(address cakeToken_, address swapRouter_) initializer public {
        cakeToken = IERC20(cakeToken_);
        swapRouter = swapRouter_;

        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN, msg.sender);
    }

    /// @inheritdoc ISoaringFund
    function stake(uint256 amount_) external {
        require(amount_ > 0, "Cannot stake 0");
        require(cakeToken.balanceOf(msg.sender) >= amount_ , "Insufficient balance");

        _increaseInvestment(msg.sender, amount_);
    }

    /// @inheritdoc ISoaringFund
    function claim() external returns (uint256) {
        return _claim(msg.sender);
    }

    /// @inheritdoc ISoaringFund
    function exitFunds() external renewPool returns (uint256) {
        require(staked[msg.sender] > 0, "No stake");

        uint256 actualClaimedAmount = _getReward(msg.sender);
        uint256 actualExitAmount = doTransferOut(address(cakeToken), msg.sender, staked[msg.sender]);

        staked[msg.sender] = 0;
        userOwnRewardPerToken[msg.sender] = 0;
        claimed[msg.sender] += actualClaimedAmount;

        totalClaimed += actualClaimedAmount;
        totalStaked -= actualExitAmount;
        totalInvest = totalFunds - actualClaimedAmount - actualExitAmount;
        emit ExitFunds(msg.sender, actualExitAmount, totalStaked);
        return actualExitAmount;
    }

    /// @inheritdoc ISoaringFund
    function setSmartChefArray(
        address[] memory smartChefArray_,
        uint256[] memory weightsArray_
    ) external renewPool onlyRole(ADMIN) {
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

    /// @inheritdoc ISoaringFund
    function updatePool() external renewPool {
        require(totalFunds > 0, "No funds");
        _updateUserRewardPerToken(address(0));
        totalInvest = totalFunds;
    }

    /// @inheritdoc ISoaringFund
    function projectEmergencyWithdraw(address[] calldata smartChefArray_, bool swapOrNot_) external onlyRole(ADMIN) {
        for (uint256 i = 0; i < smartChefArray_.length; ++i) {
            smartChef = ISmartChefInitializable(smartChefArray[i]);
            address rewardToken = smartChef.rewardToken();
            (uint256 stakedAmount,) = smartChef.userInfo(address(this));  // fetch last staked amount
            smartChef.withdraw(stakedAmount);  // withdraw all cake and rewardToken.

            smartChef.emergencyWithdraw();
            uint256 remainBalance = IERC20(rewardToken).balanceOf(address(this));
            if (swapOrNot_ && remainBalance > 0) {
                _swap(rewardToken, remainBalance);
            }
        }
    }

    /// @inheritdoc ISoaringFund
    function withdrawToken(address token, address to, uint256 amount) external onlyRole(ADMIN) {
        if (amount > 0) {
            if (token == address(0)) {
                (bool res,) = to.call{value : amount}("");
                require(res, "Transfer failed.");
            } else {
                IERC20(token).transfer(to, amount);
            }
        }
    }

    function setPath(address token_, address[] calldata swapPath_) external onlyRole(ADMIN) {
        swapPath[token_] = swapPath_;
        emit SetPath(token_, swapPath_);
    }

    function setSwapRouter(address swapRouter_) external onlyRole(ADMIN) {
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
        uint256 actualClaimedAmount = doTransferOut(address(cakeToken), to_, amount_);

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

    function _claim(address user_) internal renewPool returns (uint256) {
        uint256 actualClaimedAmount = _getReward(user_);
        require(actualClaimedAmount > 0, "No reward");
        totalInvest = totalFunds - actualClaimedAmount;
        return actualClaimedAmount;
    }

    function _increaseInvestment(address user_, uint256 amount_) internal renewPool returns (uint256) {        
        uint256 actualAddAmount;
        if (totalFunds == 0) {
            _updateUserRewardPerToken(address(0));
            actualAddAmount = _addStake(user_, amount_);
            totalInvest = actualAddAmount;
        } else {
            uint256 actualClaimedAmount = _getReward(user_);
            actualAddAmount = _addStake(user_, amount_);
            totalInvest = totalFunds - actualClaimedAmount + actualAddAmount;
        }
        return actualAddAmount;
    }

    function _addStake(address user_, uint256 amount_) internal returns (uint256) {
        uint256 actualStakedAmount = doTransferIn(address(cakeToken), user_, amount_);
        uint256 totalStakedNew = totalStaked + actualStakedAmount;
        require(totalStakedNew > totalStaked, "Total staked overflow.");

        totalStaked = totalStakedNew;
        staked[user_] += actualStakedAmount;
        emit Staked(user_, actualStakedAmount, totalStakedNew);
        return actualStakedAmount;
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
