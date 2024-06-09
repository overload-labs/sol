// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DelegationLib, Delegation, DelegationKey} from "../libraries/types/Delegation.sol";
import {UndelegationLib, Undelegation, UndelegationKey} from "../libraries/types/Undelegation.sol";

/// @title EOverload (Overload Events and Errors)
interface EOverload {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Emitted when gas budget changes for a consensus contract.
    /// @param consensus The consensus contract, also the caller.
    /// @param gas The new gas budget.
    event SetBudget(address indexed consensus, uint256 gas);
    /// @notice Emitted when undelegating delay changes for a consensus contract.
    /// @param consensus The consensus contract, also the caller.
    /// @param delay The new delay value, in seconds.
    event SetDelay(address indexed consensus, uint256 delay);
    /// @notice Emitted when `jail` cooldown changes for a consensus contract.
    /// @param consensus The consensus contract, also the caller.
    /// @param cooldown The new cooldown value, in seconds.
    event SetCooldown(address indexed consensus, uint256 cooldown);
    /// @notice Emitted when a user deposits ERC-20 tokens into the contract, using the `deposit` function.
    /// @param caller The function caller.
    /// @param owner The owner of the deposit.
    /// @param token The ERC-20 token deposited.
    /// @param amount The amount deposited.
    event Deposit(address indexed caller, address indexed owner, address indexed token, uint256 amount);
    /// @notice Emitted when a user withdraw ERC-20 tokens from the contract, using the `withdraw` function.
    /// @param caller The function caller.
    /// @param owner The owner of the tokens.
    /// @param token The ERC-20 token withdrawn.
    /// @param amount The amount withdrawn.
    event Withdraw(address indexed caller, address owner, address indexed token, uint256 amount, address recipient);
    /// @notice Emitted when a delegation object is created.
    /// @param caller The function caller.
    /// @param key The delegation key.
    /// @param position The index of the delegation object, or `-1` to find the delegation at runtime.
    /// @param amount The amount of tokens to delegate.
    /// @param data The data that is sent to before and after hooks.
    /// @param strict If true, hook reverts are bubbled up, otherwise they ignored.
    event Delegate(address indexed caller, DelegationKey indexed key, int256 position, uint256 amount, bytes data, bool strict, uint256 index);
    /// @notice Emitted when a delegation has its validator value changed.
    /// @param caller The function caller.
    /// @param from The delegation key before the change.
    /// @param to The delegation key after the change.
    /// @param position The index of the delegation object, or `-1` to find the delegation at runtime.
    /// @param data The data that is sent to before and after hooks.
    /// @param strict If true, hook reverts are bubbled up, otherwise they ignored.
    event Redelegate(address indexed caller, DelegationKey indexed from, DelegationKey indexed to, int256 position, bytes data, bool strict, uint256 index);
    /// @notice Emitted when `undelegating` is called. An undelgation object can be created depending on if delay exists.
    /// @param caller The function caller.
    /// @param key The delegation key for the delegation object to transition into an undelegation.
    /// @param amount The amount of tokens to reduce from the delegation. If full amount is entered, the delegation
    ///     object is removed.
    /// @param data The data that is sent to before and after hooks.
    /// @param strict If true, hook reverts are bubbled up, otherwise they ignored.
    event Undelegating(address indexed caller, DelegationKey indexed key, int256 position, uint256 amount, bytes data, bool strict, UndelegationKey ukey,  int256 index);
    /// @notice Emitted when `undelegate` is called and an undelegatino is removed.
    /// @param caller The function caller.
    /// @param key The undelegation key that can be used to find a generic undelegation object.
    /// @param position The assumed position of the undelegation object. Enter `-1` to loop through `undelegations`.
    /// @param data The data that is sent to before and after hooks.
    /// @param strict If true, hook reverts are bubbled up, otherwise they ignored.
    event Undelegate(address indexed caller, UndelegationKey indexed key, int256 position, bytes data, bool strict);
    /// @notice Emitted when a validator is jailed.
    /// @param consensus The consensus contract in which the validator is jailed for.
    /// @param validator The jailed validator.
    /// @param jailtime The amount of seconds the validator is jailed for.
    /// @param maturity The end date of the jail for the validator.
    event Jail(address indexed consensus, address indexed validator, uint256 jailtime, uint256 maturity);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * General errors
     */

    /// @notice Thrown when an address tries to do an unauthorized action.
    error Unauthorized();
    /// @notice Thrown when two addresses are expected to be, but are not.
    /// @param a The first value.
    /// @param b The second value.
    error MismatchAddress(address a, address b);
    /// @notice Thrown when two uint256 values are expected to be equal, but are not.
    /// @param a The first value.
    /// @param b The second value.
    error MismatchUint256(uint256 a, uint256 b);
    /// @notice Thrown when a value is not found.
    error NotFound();
    /// @notice Thrown when a value overflows some set boundaries.
    error Overflow();
    /// @notice Thrown on a fatal error.
    error Fatal();
    /// @notice Thrown when a value is expected to be defined, but is zero.
    error Zero();

    /**
     * Specific errors
     */

    /// @notice Thrown when the parameter exceeds the max allowed gas budget.
    error ValueExceedsMaxGasBudget();
    /// @notice Thrown when the parameter exceeds the max allowed delay.
    error ValueExceedsMaxDelay();
    /// @notice Thrown when the parameter exceeds the max allowed cooldown.
    error ValueExceedsMaxCooldown();
    /// @notice Thrown when the parameter is below the min allowed cooldown.
    error ValueBelowMinCooldown();
    /// @notice Thrown when the parameter exceeds the max allowed jailtime.
    error ValueExceedsMaxJailtime();
    /// @notice Thrown when max delegations are reached.
    error MaxDelegationsReached();
    /// @notice Thrown when max undelegations are reached.
    error MaxUndelegationsReached();
    /// @notice Thrown when trying to undelegate an undelegation that is not mature yet.
    error NonMatureUndelegation();
    /// @notice Thrown when a consensus contract tries to jail a validator that is on cooldown.
    error JailOnCooldown();
    /// @notice Thrown when trying to call `undelegating` on a delegation that does not exist.
    error NotDelegated();
    /// @notice Thrown when trying to call `undelegating` on a delegation that is jailed.
    error Jailed();
}
