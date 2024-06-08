// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CastLib} from "../CastLib.sol";

/// @dev `Delegation` objects are unique. There cannot be duplicates inside the mapping.
struct Delegation {
    address consensus;
    address validator;
    uint256 amount;
}

/// @dev `DelegationKey`s are used to identify the unique delegation objects.
struct DelegationKey {
    address owner;
    address token;
    address consensus;
    address validator;
}

/// @title DelegationLib
/// @notice The delegation library provides funtions to view and mutate delegation objects.
library DelegationLib {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a delegation is not found using the `get` function.
    error DelegationNotFound();

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice Looks for a matching delegation object and returns it with the index found.
    /// @param map The delegation array map.
    /// @param key The key of the delegation.
    /// @param strict Whether to strictly find a delegation or not.
    /// @return delegation The delegation object. Empty object if not found.
    /// @return index The index of the delegation object. `-1` if not found
    function get(
        mapping(address owner => mapping(address token => Delegation[])) storage map,
        DelegationKey memory key,
        bool strict
    ) internal view returns (Delegation memory delegation, int256 index) {
        int256 position_ = position(map, key);

        if (position_ >= 0) {
            index = position_;
            delegation = map[key.owner][key.token][CastLib.u256(index)];
        } else {
            if (strict) {
                revert DelegationNotFound();
            } else {
                index = -1;
                delegation = zero();
            }
        }
    }

    /// @notice Returns the index of a delegation object if found.
    /// @param map The delegation array map.
    /// @param key The key of the delegation.
    function position(
        mapping(address owner => mapping(address token => Delegation[])) storage map,
        DelegationKey memory key
    ) internal view returns (int256) {
        Delegation[] memory delegations = map[key.owner][key.token];

        for (uint256 i = 0; i < delegations.length; i++) {
            Delegation memory delegation = delegations[i];

            if (key.consensus == delegation.consensus && key.validator == delegation.validator) {
                return CastLib.i256(i);
            }
        }

        return -1;
    }

    /// @notice Returns the max value of the delegations objects.
    /// @param map The delegation array map.
    /// @param owner The owner of the delegation objects.
    /// @param token The token of the delegation objects.
    function max(
        mapping(address owner => mapping(address token => Delegation[])) storage map,
        address owner,
        address token
    ) internal view returns (uint256 value) {
        Delegation[] memory delegations = map[owner][token];

        for (uint256 i = 0; i < delegations.length; i++) {
            Delegation memory delegation = delegations[i];

            if (delegation.amount > value) {
                value = delegation.amount;
            }
        }
    }

    /// @notice Returns an empty delegation object.
    function zero() internal pure returns (Delegation memory) {
        return Delegation({
            consensus: address(0),
            validator: address(0),
            amount: 0
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 MUTATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Increases the delegation object's `amount` by `delta`.
    /// @param map The delegation array map.
    /// @param owner The owner of the delegation object.
    /// @param token The token of the delegation object.
    /// @param index The index of the delegation object in the array.
    /// @param delta The amount to increase `amount` value by for the delegation object.
    function increase(
        mapping(address owner => mapping(address token => Delegation[])) storage map,
        address owner,
        address token,
        uint256 index,
        uint256 delta
    ) internal returns (Delegation memory) {
        map[owner][token][index].amount += delta;
        return map[owner][token][index];
    }

    /// @notice Decreases the delegation object's `amount` by `delta`.
    /// @param map The delegation array map.
    /// @param owner The owner of the delegation object.
    /// @param token The token of the delegation object.
    /// @param index The index of the delegation object in the array.
    /// @param delta The amount to decrease `amount` value by for the delegation object.
    function decrease(
        mapping(address owner => mapping(address token => Delegation[])) storage map,
        address owner,
        address token,
        uint256 index,
        uint256 delta
    ) internal returns (Delegation memory) {
        map[owner][token][index].amount -= delta;
        return map[owner][token][index];
    }

    /// @notice Add a delegation object to the delegations array.
    /// @param map The delegation array map.
    /// @param key The delegation key to add.
    /// @param amount The amount of tokens to add to the delegation.
    /// @return delegation The delegation object added to the array.
    /// @return index The index of the added delegation object.
    function add(
        mapping(address owner => mapping(address token => Delegation[])) storage map,
        DelegationKey memory key,
        uint256 amount
    ) internal returns (Delegation memory delegation, uint256 index) {
        index = map[key.owner][key.token].length;
        map[key.owner][key.token].push(
            delegation = Delegation({
                consensus: key.consensus,
                validator: key.validator,
                amount: amount
            })
        );
    }

    /// @notice Remove a delegation object from the delegations array.
    /// @param map The delegation array map.
    /// @param owner The owner of the delegation object.
    /// @param token The token of the delegation object.
    /// @param index The index of the delegation object.
    function remove(
        mapping(address owner => mapping(address token => Delegation[])) storage map,
        address owner,
        address token,
        uint256 index
    ) internal returns (Delegation memory removed) {
        Delegation[] storage delegations = map[owner][token];

        removed = delegations[index];
        delegations[index] = delegations[delegations.length - 1];
        delegations.pop();
    }
}
