// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

interface ISoaringFund {
    /**
     * @notice staked token.
     * @param amount_: amount to stake (in stakedToken)
     */
    function stake(uint256 amount_) external;

    /**
     * @notice claim reward.
     * @return reward amount.
     */
    function claim() external returns (uint256);

    /**
     * @notice exit funds and withdraw reward.
     * @return reward amount.
     */
    function exitFunds() external returns (uint256);

    /**
     * @notice set smartChefArray and weightsArray.
     * @param smartChefArray_: array of smartChef address.
     * @param weightsArray_: array of weight.
     */
    function setSmartChefArray(address[] memory smartChefArray_, uint256[] memory weightsArray_) external;

    /**
     * @notice redeem funds and reinvest.
     */
    function updatePool() external;

    /**
     * @notice project emergency withdraw.
     * @param smartChefArray_: array of smartChef address.
     * @param swapOrNot_: swap or not.
     */
    function projectEmergencyWithdraw(address[] calldata smartChefArray_, bool swapOrNot_) external;

    /**
     * @notice withdraw token.
     * @param token: token address.
     * @param to: to address.
     * @param amount: amount to withdraw.
     */
    function withdrawToken(address token, address to, uint256 amount) external;

    /**
     * @notice set path.
     * @param token_: token address.
     * @param swapPath_: swap path.
     */
    function setPath(address token_, address[] calldata swapPath_) external;

    /**
     * @notice set swapRouter.
     * @param swapRouter_: swapRouter address.
     */
    function setSwapRouter(address swapRouter_) external;
}