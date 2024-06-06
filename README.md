<div align="center">
  <h1>Overload</h1>
</div>
<p align="center">
  The Universal Restaking Layer
</p>
<br />

This repository contains the core contract, `Overload.sol`, for Overload. AVSs built on top of `Overload.sol` is expected to implement `IHOverload.sol` which is the interface for hook callbacks.

## Contracts

```
lib/
├─ forge-std
├─ openzeppelin-contracts
└─ solmate

src/
├─ abstracts/
│  ├─ COverload.sol
│  └─ Lock.sol
├─ interfaces/
│  ├─ IHOverload.sol
│  └─ IOverload.sol
├─ libraries/
│  ├─ types/
│  │  ├─ Delegation.sol
│  │  └─ Undelegation.sol
│  ├─ CastLib.sol
│  ├─ FunctionCallLib.sol
│  ├─ HookCallLib.sol
│  └─ TokenIdLib.sol
├─ tokens/
│  └─ ERC6909.sol
└─ Overload.sol
```

## Overview

`Overload.sol` contract accounts for deposited tokens using the `ERC-6909.sol` standard. When ERC-20 tokens are deposited using the `deposit` function, balance is credited to the `owner` in the ERC-6909 `balanceOf` mapping.

Hence, token address of type `address` will be casted to `uint256` and will take up `160 bits` of data. This also ensures every token id is unique and makes ERC-6909 fully compatible with ERC-20 for accounting the tokens internally in the contract.

### Restaking

After depositing tokens into `Overload.sol`, it becomes possible to `delegate` any amount of `balanceOf` value to any address. The delegation interface looks as follows

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

The types that restaked instances can takes on are 

- `Delegation`
- `Undelegation`

and the three state transitions are strictly

- `delegate`: Creates a restaking object and saves it into `delegations` mapping. Will increase bonding if and only if the restaked amount is greater than what's currently `bonded`.
- `undelegating`: State transitions a restaked instance into `undelegations` mapping.
- `undelegate`: After the `Undelegation` has finished the withdrawal delay, the restaked instance can be `undelegated` which deletes the restaked instance and possibly frees up `bonded` tokens into `balanceOf` (depends if there are other restaked instances, and what their values are).

that can be called to move between all states.

The exact possible state transistions are as follows.

| State | Context | Transition/Function | Result |
| :--- | :--- | :--- | :--- |
| `Balance` | None | `delegate` | `Delegation` |
| `Delegation` | None | `redelegate` | `Delegation` |
| `Delegation` | Without undelegation delay | `undelegating` | `Balance` |
| `Delegation` | With undelegation delay | `undelegating` | `Undelegation` |
| `Undelegation` | Before undelegation delay has passed | `undelegate` | `REVERT` |
| `Undelegation` | After undelegation delay has passed | `undelegate` | `Balance` |

The balance increase or decreases based on the state transisions and on the amount being moved.

| Transition/Function | Result |

### Strict Mode

The main interface for Overload that users are expected to interact with are the six methods in the below.

| Method | Strict Mode |
| :--- | :--- |
| `deposit` | None |
| `withdraw` | None |
| `delegate` | Optional, but expected to be `true` by consensus contracts |
| `redelegate` | Yes |
| `undelegating` | Optional |
| `undelegate` | Optional |

The table above enables users to restake to any external contract without falling trap to risking malicious code. We will walk through the examples below of an example implementation that covers perspectives from both `Overload.sol` and and `Consensus.sol` (AVS) contract.

### Hooks

When building a consensus contract inheriting `IHOverload.sol` fully, we expect the behaviour to be as follows.

| Hooks | Strict Mode | Result |
| :--- | :--- | :--- |
| `beforeDelegate`, `afterDelegate` | Yes | `OK` |
| `beforeDelegate`, `afterDelegate` | No | Do nothing. If the hook call fails, then the consensus contract should not register anything. |
| `beforeUndelegation`, `afterUndelegation` | Yes | `OK` |
| `beforeUndelegation`, `afterUndelegation` | No | This is where the consensus contract needs to work within the `gasBudget` of `1_000_000`, as `Overload.sol` will guarantee that. Consensus contracts that use more than `1_000_000` is undefined behaviour. |
| `beforeRedelegate`, `afterRedelegate` | Yes | `OK` |
| `beforeRedelegate`, `afterRedelegate` | No | The hook calls have a gas budget of `1_000_000`, otherwise undefined behaviour. |
| `beforeUndelegate`, `afterUndelegate` | Yes | `OK` |
| `beforeUndelegate`, `afterUndelegate` | No | The hook calls have a gas budget of `1_000_000`, otherwise undefined behaviour. |

The gas budget pattern is important to prevent consensus contracts holding assets hostage. This way, a restaker will always be able to withdraw their assets regardless of external contract code, and a consensus contract can enforce correct behaviour as long as the gas used for code execution stays below `1_000_000` gas units.

The `strict` variable prevents consensus contracts from `revert`:ing `undelegating` or `undelegate` calls, so that users will always be able to remove a restaking. The fixed gas budget on the other hand, is important to avoid an additonal `out-of-gas` attacks that consensus contract would otherwise be able to perform. A solution would be for the user to increase their gas limit very high, taking into account the `63 / 64` rule where a `1 / 63` out of the gas would be enough to fully complete the rest of the outer most function call. Relying on the `63 / 64` implies no limit on the gas budget but worse ergonomics; hence, `Overload.sol` instead employs a fixed gas budget that is within reason for the final implementation.

Hooks in Overload differ from e.g. Uniswap V4. Instead of having hook permissions included in the addresses, we instead utilize the commonly used ERC-165 standard instead. If a contract returns true for a hook method interface from `IHOverload.sol`, then `Overload.sol` will try to call the hook on the target contract.
