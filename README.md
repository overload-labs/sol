<div align="center">
  <h1>Overload</h1>
</div>
<p align="center">
  The Universal Restaking Layer
</p>
<br />

This repository contains the core contracts for Overload, more specifically, the `Overload.sol` contract.

## Overview

`Overload.sol` contract accounts for deposited tokens using the `ERC-6909.sol` standard. When ERC-20 tokens are deposited using the `deposit` function, balance is creditted to the `owner` in ERC-6909's `balanceOf` mapping.

After depositing tokens into `Overload.sol`, it becomes possible to `delegate` any amount of `balanceOf` value, to any address. The delegation interface looks as follows

```solidity
function delegate(DelegationKey memory key, uint256 delta, bytes calldata data, bool strict) external returns (bool);
```

where the `DelegationKey` data structure is defined as

```
/// @dev `DelegationKey`s are used to identify the unique Delegation objects.
struct DelegationKey {
    address owner;
    address token;
    address consensus;
    address validator;
}
```

. There are two values to keep track of canonical/underlying balances, and two states and three state transistions for restaked balances.

- `balanceOf`: The default token balance for any ERC-20 token, mirrored as ERC-6909 tokens. This token balance can be deposited/withdrawn from without any restrictions. They are identical to ERC-20 token balances.
- `bonded`: When tokens are restaked using a `DelegationKey`, tokens will be locked according to `max(d_0, ..., d_n)`, where `d_i` is the delegation amount for a restaking instance.

The states that restaked instances can takes on are 

- `Delegation`
- `Undelegating`

and the three state transitions are strictly

- `delegate`: Creates a restaking object and saves it into `delegations` mapping. Will increase bonding if and only if the restaked amount is greater than what's currently `bonded`.
- `undelegating`: State transitions a restaked instance into `undelegations` mapping.
- `undelegate`: After the `Undelegating` has finished the withdrawal delay, the restaked instance can be `undelegated` which deletes the restaked instance and possibly frees up `bonded` tokens into `balanceOf` (depends if there are other restaked instances, and what their values are).

that can be called to move between all states.

The main interface for Overload that users are expected to interact with are the six methods in the below.

| Method | Strict Mode |
| :--- | :--- |
| deposit | None |
| withdraw | None |
| delegate | Optional, but expected to be true |
| redelegate | Yes |
| undelegating | Optional |
| undelegate | Optional |

The table above enables users to restake to any external contract without falling trap to risking malicious code. We will walk through the examples below of an example implementation that covers perspectives from both `Overload.sol` and and `Consensus.sol` (AVS) contract.

## Build

To build the contracts, run:

```
forge build
```
