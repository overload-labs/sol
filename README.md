<div align="center">
  <h1>Overload</h1>
</div>
<p align="center">
  The Universal Restaking Layer
</p>
<br />

This repository contains the core contract, `Overload.sol`, for Overload. The AVSs that build on top of `Overload.sol` is expected to implement the `IHOverload.sol` hook interace.

## Contracts

```ml
lib/
├─ forge-std
├─ openzeppelin-contracts
└─ solmate

src/
├─ abstracts/
│  ├─ COverload.sol - "The hook call logic for Overload.sol"
│  └─ Lock.sol - "Reentrancy guard"
├─ interfaces/
│  ├─ IHOverload.sol - "Interface for AVSs that implement Overload.sol hooks"
│  └─ IOverload.sol - "Interface for Overload.sol"
├─ libraries/
│  ├─ types/
│  │  ├─ Delegation.sol - "The delegation type, created when `delegate` is called"
│  │  └─ Undelegation.sol - "The undelegation type, created when `undelegating` is called"
│  ├─ CastLib.sol - "Safe casting library"
│  ├─ FunctionCallLib.sol - "Address calls, partially forked from OpenZeppelin's Address.sol library"
│  ├─ HookCallLib.sol - "Hook call logic that COverload.sol utilizes"
│  └─ TokenIdLib.sol - "Convert `address` to `uint256` and vice versa"
├─ tokens/
│  └─ ERC6909.sol - "Forked from Uniswap V4"
└─ Overload.sol - "The core contract"

test/
├─ mocks/
├─ Overoad.consensus.t.sol - "Test malicious consensus contracts."
└─ Overload.t.sol - "Test Overload.sol generally"
```

## Overview

`Overload.sol` contract accounts for deposited tokens using the `ERC-6909.sol` standard. When ERC-20 tokens are deposited using the `deposit` function, balance is credited to the `owner` in the ERC-6909 `balanceOf` mapping.

Hence, token address of type `address` will be casted to `uint256` and will take up `160 bits` of data. This also ensures every token id is unique and makes ERC-6909 fully compatible with ERC-20 for accounting the tokens internally in the contract.

### Restaking Types

There are two types in the restaking contract:

- `Delegation`: When `delegate` is called, tokens can be bonded from `balanceOf` which then creates a `Delegation`.
- `Undelegation`: When `undelegating` is called, an `Undelegation` object can be creaated depending on whether `withdrawalDelay` is `0` or non-zero.

For identifying a specific `Delegation` or `Undelegation` object, there are two key types:

```solidity
/// @dev `DelegationKey`s are used to identify Delegation objects.
/// @dev `DelegationKey`s are unique, i.e. a single `DelegationKey` will map to exactly one `Delegation`.
struct DelegationKey {
    address owner;
    address token;
    address consensus;
    address validator;
}

/// @dev `UndelegationKey`s are used to identify Undelegation objects.
/// @dev `UndelegationKey`s are non-unique, two `Undelegation`s can exist for one `UndelegationKey`.
///     The `position` argument in `undelegate` is how `Overload.sol` tells these objects apart.
struct UndelegationKey {
    address owner;
    address token;
    address consensus;
    address validator;
    uint256 amount;
    uint256 completion;
}
```

There are two values to keep track of: the canonical/underlying balance, and the restaked/bonded balance.

- `balanceOf`: The default token balance for any ERC-20 token, mirrored as ERC-6909 tokens. This token balance can be deposited/withdrawn from without any restrictions. They are identical to ERC-20 token balances, but inside `Overload.sol`.
- `bonded`: When tokens are restaked using the `delegate` function, tokens will be locked according to `max(d_0, ..., d_n)`, where `d_i` is the delegation amount for a restaking instance.

The five main state transitions are:

- `delegate`: Creates a restaking object and saves it into `delegations` mapping. Will increase bonding if and only if the restaked amount is greater than what's currently `bonded`.
- `redelegate`: Modifes the `validator` value inside a `Delegation`. No additional delay to change validators.
- `undelegating`: State transitions a restaked instance into `undelegations` mapping.
- `undelegate`: After the `Undelegation` has finished the withdrawal delay, the restaked instance can be `undelegated` which deletes the restaked instance and possibly frees up `bonded` tokens into `balanceOf` (depends if there are other restaked instances, and what their values are).
- `jail`: A consensus contract can jail a validator, which prevents assets from being withdrawn until a specified timestamp. A validator cannot be continously jailed, which prevents infinite jailing and would imply soft-locked assets. Instead, there's a `jailCooldown` window in-between jailings that a validator can utilize to escape a malicious consensus contract that e.g. jails everyone.

Showing the possible state transisions below, as a table (`redelegate` and `jail` excluded):

| State | Context | Transition/Function | Result |
| :--- | :--- | :--- | :--- |
| `Balance` | None | `delegate` | `Delegation` |
| `Delegation` | None | `redelegate` | `Delegation` |
| `Delegation` | Without undelegation delay | `undelegating` | `Balance` |
| `Delegation` | With undelegation delay | `undelegating` | `Undelegation` |
| `Undelegation` | Before undelegation delay has passed | `undelegate` | `REVERT` |
| `Undelegation` | After undelegation delay has passed | `undelegate` | `Balance` |

And a table for the balance increase/decreases, based on the state transisions, and on the amount being moved:

| Transition/Function | Context | Result |
| :--- | :--- | :--- |
| `delegate` | `amount > max(d_0, ..., d_n)` | Increase bonded tokens to `amount` |
| `delegate` | `amount <= max(d_0, ..., d_n)` | Do nothing |
| `undelegating` | `amount == max(d_0, ..., d_n)` | Do nothing |
| `undelegating` | `amount < max(d_0, ..., d_n)` | Do nothing |
| `undelegating` | `amount == max(d_0, ..., d_n)` (Without delay) | Decrease bonded tokens |
| `undelegating` | `amount < max(d_0, ..., d_n)` (Without delay) | Do nothing |
| `undelegate` | `amount == max(d_0, ..., d_n)` | Decrease bonded tokens to `max(d_0, ..., d_n)` excluding the current undelegated |
| `undelegate` | `amount < max(d_0, ..., d_n)` | Do nothing |

The amount being freed or bonded is mainly managed by the internal `_bondTokens` and `_bondUpdate` functions in `Overload.sol`.

### Strict Mode

Strict mode is a feature that can be enabled or disabled by the user themself on `Overload.sol` state transision calls (`delegate`, etc.).

If `strict` is true, hook calls that revert ***will*** revert the whole transaction.
If `strict` is false, hook calls that revert ***will not*** revert the whole transaction.

Below is a table of how consensus contracts are expected to read the `strict` parameter in hook calls.

| Method | Strict Mode |
| :--- | :--- |
| `deposit` | None |
| `withdraw` | None |
| `delegate` | Optional, but expected to be `true` by consensus contracts using a `require` assertion.  |
| `redelegate` | Optional |
| `undelegating` | Optional |
| `undelegate` | Optional |

When a consensus contract has `require(strict == true, StrictFalse())` assertion in the code for `beforeDelegate` hook call, this then implements the correct behaviour (besides the point that gas never exceeds `1_000_000`, which would also be fine). As long as the restake accounting is synced corretly between the consensus contract and in the `Overload.sol`, then everything is fine (made possible by assertions and being below `1_000_000` gas consumed in the hook call).

The table above enables users to restake to any external contract and always be able to retain the ability to undelegate. We will walk through the examples below of an example implementation that covers perspectives from both `Overload.sol` and and `Consensus.sol` (AVS) contract.

### Hooks

When building a consensus contract inheriting `IHOverload.sol` fully, the behaviour should be as follows.

| Hooks | Strict Mode | Result |
| :--- | :--- | :--- |
| `beforeDelegate`, `afterDelegate` | Yes | `OK` |
| `beforeDelegate`, `afterDelegate` | No | Do nothing. As `delegate` is the entry function, a consensus contract can enforce the user to have `strict` as `true`. |
| `beforeUndelegation`, `afterUndelegation` | Yes | `OK` |
| `beforeUndelegation`, `afterUndelegation` | No | This is where the consensus contract needs to work within the `gasBudget` of `1_000_000`, as `Overload.sol` guarantees that in the hook call. Consensus contracts that use more than `1_000_000` in their hook calls are deemed as undefined behaviour. |
| `beforeRedelegate`, `afterRedelegate` | Yes | `OK` |
| `beforeRedelegate`, `afterRedelegate` | No | The hook calls have a gas budget of `1_000_000`, otherwise undefined behaviour. |
| `beforeUndelegate`, `afterUndelegate` | Yes | `OK` |
| `beforeUndelegate`, `afterUndelegate` | No | The hook calls have a gas budget of `1_000_000`, otherwise undefined behaviour. |

The gas budget pattern is important to prevent consensus contracts holding assets hostage. This way, a restaker will always be able to withdraw their assets regardless of external contract code, and a consensus contract can enforce correct behaviour as long as the gas used for code execution stays below `1_000_000` gas units.

The `strict` variable prevents consensus contracts from `revert`:ing `undelegating` or `undelegate` calls, so that users will always be able to remove a restaking. The fixed gas budget on the other hand, is important to avoid an additonal `out-of-gas` attacks that consensus contract would otherwise be able to perform. A solution would be for the user to increase their gas limit very high, taking into account the `63 / 64` rule where a `1 / 63` out of the gas would be enough to fully complete the rest of the outer most function call. Relying on the `63 / 64` implies no limit on the gas budget but worse ergonomics; hence, `Overload.sol` instead employs a fixed gas budget that is within reason for the final implementation.

Hooks in Overload differ from e.g. Uniswap V4. Instead of having hook permissions included in the addresses, we instead utilize the commonly used ERC-165 standard instead. If a contract returns true for a hook method interface from `IHOverload.sol`, then `Overload.sol` will try to call the hook on the target contract.

## Coverage

```sh
forge coverage --ir-minimum
```

```
| File                                 | % Lines          | % Statements     | % Branches      | % Funcs        |
|--------------------------------------|------------------|------------------|-----------------|----------------|
| src/Overload.sol                     | 88.98% (113/127) | 88.81% (127/143) | 27.78% (25/90)  | 77.78% (14/18) |
| src/abstracts/COverload.sol          | 100.00% (16/16)  | 100.00% (16/16)  | 100.00% (16/16) | 100.00% (8/8)  |
| src/abstracts/Lock.sol               | 100.00% (3/3)    | 100.00% (3/3)    | 0.00% (0/2)     | 100.00% (1/1)  |
| src/libraries/CastLib.sol            | 100.00% (4/4)    | 100.00% (6/6)    | 0.00% (0/4)     | 100.00% (2/2)  |
| src/libraries/FunctionCallLib.sol    | 83.33% (10/12)   | 73.33% (11/15)   | 50.00% (5/10)   | 66.67% (2/3)   |
| src/libraries/HookCallLib.sol        | 75.00% (6/8)     | 80.00% (8/10)    | 50.00% (2/4)    | 100.00% (1/1)  |
| src/libraries/TokenIdLib.sol         | 33.33% (1/3)     | 33.33% (1/3)     | 0.00% (0/2)     | 50.00% (1/2)   |
| src/libraries/types/Delegation.sol   | 93.10% (27/29)   | 92.11% (35/38)   | 87.50% (7/8)    | 100.00% (8/8)  |
| src/libraries/types/Undelegation.sol | 89.29% (25/28)   | 86.49% (32/37)   | 35.71% (5/14)   | 83.33% (5/6)   |
| src/tokens/ERC6909.sol               | 41.67% (10/24)   | 35.71% (10/28)   | 0.00% (0/4)     | 57.14% (4/7)   |
| test/mocks/ConsensusMock.sol         | 100.00% (10/10)  | 100.00% (18/18)  | 100.00% (0/0)   | 100.00% (1/1)  |
| Total                                | 85.23% (225/264) | 84.23% (267/317) | 38.96% (60/154) | 82.46% (47/57) |
```
