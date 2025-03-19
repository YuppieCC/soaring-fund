# SoaringFund

SoaringFund is a yield optimization protocol built on top of PancakeSwap's farming pools. It enables users to stake CAKE tokens and automatically distributes them across multiple farming pools according to a configurable weight system to maximize returns.

## Overview

SoaringFund simplifies the DeFi farming experience by automatically:

- Distributing staked CAKE tokens across multiple PancakeSwap SmartChef pools
- Harvesting rewards and swapping them back to CAKE
- Reinvesting the rewards to compound yields
- Allowing users to claim rewards or exit at any time

The protocol uses a reward distribution mechanism that fairly allocates rewards to users based on their stake proportion and duration.

## Smart Contract Architecture

The main components of the system include:

- `SoaringFund.sol`: The main contract that handles staking, claiming, and fund management
- Integration with PancakeSwap's SmartChef farming pools
- Integration with PancakeSwap's Router for token swaps

## Setup

### Installation

1. Clone the repository:

```bash
git clone https://github.com/yourusername/soaringfund.git
cd soaringfund
```

2. Install dependencies:

```bash
forge install
```

3. Compile the contracts:

```bash
forge build
```

### Configuration

Create a `.env` file in the root directory with the following variables:

```
PRIVATE_KEY=your_private_key
BSC_RPC_URL=https://bsc-dataseed.binance.org/
BSC_TESTNET_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545/
BSCSCAN_API_KEY=your_bscscan_api_key
```

## Usage

### Admin Functions

#### Initialize the Contract

The contract needs to be initialized with the CAKE token address and PancakeSwap router:

```solidity
function initialize(address cakeToken_, address swapRouter_)
```

#### Configure Farming Pools

Admins can set which SmartChef contracts to use and their corresponding weight allocation:

```solidity
function setSmartChefArray(address[] memory smartChefArray_, uint256[] memory weightsArray_)
```

The weights should add up to 1e9 (1 billion) to represent 100%.

#### Configure Swap Paths

Set the token swap path for converting reward tokens back to CAKE:

```solidity
function setPath(address token_, address[] calldata swapPath_)
```

#### Emergency Functions

In case of emergency, admins can withdraw all funds from the farming pools:

```solidity
function projectEmergencyWithdraw(address[] calldata smartChefArray_, bool swapOrNot_)
```

### User Functions

#### Stake CAKE Tokens

Users can stake CAKE tokens to participate in the protocol:

```solidity
function stake(uint256 amount_)
```

#### Claim Rewards

Users can claim their accumulated CAKE rewards:

```solidity
function claim()
```

#### Exit the Protocol

Users can withdraw their staked tokens and claim rewards in one transaction:

```solidity
function exitFunds()
```

#### Add More Funds to the Protocol

Additional liquidity can be added to the protocol:

```solidity
function addFunds(uint256 amount_)
```

## Security Features

The contract implements several security features:

- `ReentrancyGuard`: Prevents reentrancy attacks
- `RoleControl`: Role-based access control for admin functions
- `TokenTransfer`: Safe token transfer utilities

## License

This project is licensed under the MIT License - see the LICENSE file for details. 