// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Delegation, DelegationKey} from "../libraries/types/Delegation.sol";
import {Undelegation, UndelegationKey} from "../libraries/types/Undelegation.sol";

/// @title HOverload (Overload Hooks)
interface HOverload {
    /*//////////////////////////////////////////////////////////////
                                DELEGATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The before `delegate` hook.
    /// @param sender The caller.
    /// @param key The delegation key.
    /// @param delta The amount of tokens to delegate.
    /// @param data The data sent to this hook.
    /// @param strict If true, then hook reverts are bubbled up, otherwise they are ignored.
    function beforeDelegate(address sender, DelegationKey memory key, uint256 delta, bytes calldata data, bool strict) external returns (bytes4);

    /// @notice The after `delegate` hook
    /// @param sender The caller.
    /// @param key The delegation key.
    /// @param delta The amount of tokens to delegate.
    /// @param data The data sent to this hook.
    /// @param strict If true, then hook reverts are bubbled up, otherwise they are ignored.
    /// @param delegation The delegation object that was created.
    /// @param index The index of the created delegation object.
    function afterDelegate(address sender, DelegationKey memory key, uint256 delta, bytes calldata data, bool strict, Delegation memory delegation, uint256 index) external returns (bytes4);

    /*//////////////////////////////////////////////////////////////
                               REDELEGATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The before `redelegate` hook.
    /// @param sender The caller.
    /// @param from The before delegation key.
    /// @param to The after delegation key.
    /// @param data The data sent to this hook.
    /// @param strict If true, then hook reverts are bubbled up, otherwise they are ignored.
    function beforeRedelegate(address sender, DelegationKey memory from, DelegationKey memory to, bytes calldata data, bool strict) external returns (bytes4);

    /// @notice The after `redelegate` hook.
    /// @param sender The caller.
    /// @param from The before delegation key.
    /// @param to The after delegation key.
    /// @param data The data sent to this hook.
    /// @param strict If true, then hook reverts are bubbled up, otherwise they are ignored.
    function afterRedelegate(address sender, DelegationKey memory from, DelegationKey memory to, bytes calldata data, bool strict) external returns (bytes4);

    /*//////////////////////////////////////////////////////////////
                              UNDELEGATING
    //////////////////////////////////////////////////////////////*/    

    /// @notice The before `undelegating` hook.
    /// @param sender The caller.
    /// @param key The delegation key.
    /// @param delta The amount of tokens to reduce from the delegation, and amount of tokens to add to a new undelegation.
    /// @param data The data sent to this hook.
    /// @param strict If true, then hook reverts are bubbled up, otherwise they are ignored.
    /// @param delegationIndex The index of the found delegation object.
    function beforeUndelegating(address sender, DelegationKey memory key, uint256 delta, bytes calldata data, bool strict, uint256 delegationIndex) external returns (bytes4);

    /// @notice The after `undelegating` hook.
    /// @param sender The caller.
    /// @param key The delegation key.
    /// @param delta The amount of tokens to reduce from the delegation, and amount of tokens to add to a new undelegation.
    /// @param data The data sent to this hook.
    /// @param strict If true, then hook reverts are bubbled up, otherwise they are ignored.
    /// @param ukey The created undelegation object.
    /// @param undelegatingIndex The index of the created undelegation object.
    function afterUndelegating(address sender, DelegationKey memory key, uint256 delta, bytes calldata data, bool strict, UndelegationKey memory ukey, uint256 undelegatingIndex) external returns (bytes4);

    /*//////////////////////////////////////////////////////////////
                               UNDELEGATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The before `undelegate` hook.
    /// @param sender The caller.
    /// @param key The non-unique undelegation key.
    /// @param position The index of the undelegation object, or `-1` to find the undelegation at runtime.
    /// @param data The data sent to this hook.
    /// @param strict If true, then hook reverts are bubbled up, otherwise they are ignored.
    /// @param index The index of the found undelegation object.
    function beforeUndelegate(address sender, UndelegationKey memory key, int256 position, bytes calldata data, bool strict, uint256 index) external returns (bytes4);

    /// @notice The after `undelegate` hook.
    /// @param sender The caller.
    /// @param key The undelegation key.
    /// @param position The index of the undelegation object, or `-1` to find the undelegation at runtime.
    /// @param data The data sent to this hook.
    /// @param strict If true, then hook reverts are bubbled up, otherwise they are ignored.
    function afterUndelegate(address sender, UndelegationKey memory key, int256 position, bytes calldata data, bool strict) external returns (bytes4);
}
