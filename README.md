# MultiSigWallet

## Overview

MultiSigWallet is a smart contract written in Solidity that implements a multi-signature wallet with proposal and execution functionalities. The contract allows two directors to create and execute proposals for modifying wallet parameters, such as the receiver wallet address, wallet name, and the USD value of ETH for triggering transfers.

## Features

- **Proposal System**: Directors can create proposals to modify wallet parameters.
- **Multi-Signature Approval**: Proposals require approval from both directors to be executed.
- **Wallet Parameter Modification**: Accepted proposals can update the receiver wallet, wallet name, and USD value of ETH.
- **Funds Transfer**: The contract can transfer its Ether balance to the designated receiver wallet.
- **ETH Balance Check**: A function allows checking if the ETH balance in USD value is above a specified threshold.
- **Chainlink Integration**: The contract uses the Chainlink ETH/USD price feed for accurate USD value calculations.

## Contract Functions

### `makeProposal`

```solidity
function makeProposal(
    address _receiverWallet,
    string memory _name,
    uint256 _usdValue
) external onlyDirector;
```

Creates a new proposal for modifying wallet parameters.

### `executeAction`

```solidity
function executeAction(
    uint256 proposalId,
    bool accept
) external onlyDirector notCreator(proposalId);
```

Executes an accepted proposal to modify wallet parameters.

### `transferFunds`

```solidity
function transferFunds() external;
```

Transfers the Ether balance to the designated receiver wallet.

### `checkEthBalanceVsUSD`

```solidity
function checkEthBalanceVsUSD() external view returns (bool);
```

Checks if the ETH balance in USD value is greater than or equal to the specified threshold.

### `getPrice`

```solidity
function getPrice() public view returns (uint256);
```

Gets the latest ETH/USD price from the Chainlink aggregator.
