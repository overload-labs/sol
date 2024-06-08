// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CastLib} from "../CastLib.sol";

/// @dev The undelegation objects are non-unique.
/// @dev A pair of (UndelegationKey, index) is unique.
struct Undelegation {
    address consensus;
    address validator;
    uint256 amount;

    uint256 maturity; // a unix timestamp in seconds
}

/// @dev The identifier for any matching undelegation object.
struct UndelegationKey {
    address owner;
    address token;
    address consensus;
    address validator;
    uint256 amount;
    uint256 maturity;
}

/// @title UndelegationLib
library UndelegationLib {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an undelegation is not found using the `get` function.
    error UndelegationNotFound();

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice Looks for a matching undelegation object and returns it with the index found.
    /// @param map The undelegation array map.
    /// @param key The key of the undelegation.
    /// @param strict Whether to strictly find a undelegation or not.
    /// @return undelegation The undelegation object. Empty object if not found.
    /// @return index The index of the undelegation object. `-1` if not found
    function get(
        mapping(address owner => mapping(address token => Undelegation[])) storage map,
        UndelegationKey memory key,
        bool strict
    ) internal view returns (Undelegation memory undelegation, int256 index) {
        int256 position_ = position(map, key);

        if (position_ >= 0) {
            index = position_;
            undelegation = map[key.owner][key.token][CastLib.u256(index)];
        } else {
            if (strict) {
                revert UndelegationNotFound();
            } else {
                index = -1;
                undelegation = zero();
            }
        }
    }

    /// @notice Returns the index of an undelegation object if found.
    /// @dev Undelegations are not unique, even with maturity timestamp are included. Although, this is fine as two
    ///     identital keys are effectively also imply objects being identical. Hence, fetching for an object with a key
    ///     will return the first match.
    /// @param map The undelegation array map.
    /// @param key The key of the undelegation.
    function position(
        mapping(address owner => mapping(address token => Undelegation[])) storage map,
        UndelegationKey memory key
    ) internal view returns (int256) {
        for (uint256 i = 0; i < map[key.owner][key.token].length; i++) {
            Undelegation memory undelegation = map[key.owner][key.token][i];

            if (
                key.consensus == undelegation.consensus &&
                key.validator == undelegation.validator &&
                key.amount == undelegation.amount &&
                key.maturity == undelegation.maturity
            ) {
                return CastLib.i256(i);
            }
        }

        return -1;
    }

    /// @notice Returns an empty undelegation object.
    function zero() internal pure returns (Undelegation memory) {
        return Undelegation({
            consensus: address(0),
            validator: address(0),
            amount: 0,
            maturity: 0
        });
    }

    /// @notice Returns an empty undelegation key.
    function zeroKey() internal pure returns (UndelegationKey memory) {
        return UndelegationKey({
            owner: address(0),
            token: address(0),
            consensus: address(0),
            validator: address(0),
            amount: 0,
            maturity: 0
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 MUTATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Add an udelegation object to the undelegations array.
    /// @param map The undelegation array map.
    /// @param key The undelegation key to add.
    function add(
        mapping(address owner => mapping(address token => Undelegation[])) storage map,
        UndelegationKey memory key
    ) internal returns (uint256 index) {
        index = map[key.owner][key.token].length;
        map[key.owner][key.token].push(Undelegation({
            consensus: key.consensus,
            validator: key.validator,
            amount: key.amount,
            maturity: key.maturity
        }));
    }

    /// @notice Remove an undelegation object from the undelegations array.
    /// @param map The undelegation array map.
    /// @param key The key of the undelegation object.
    /// @param index The index of the undelegation object.
    function remove(
        mapping(address owner => mapping(address token => Undelegation[])) storage map,
        UndelegationKey memory key,
        uint256 index
    ) internal returns (Undelegation memory removed) {
        Undelegation[] storage undelegations = map[key.owner][key.token];

        removed = undelegations[index];
        require(removed.consensus == removed.consensus);
        require(removed.validator == removed.validator);
        require(removed.amount == removed.amount);
        require(removed.maturity == removed.maturity);

        undelegations[index] = undelegations[undelegations.length - 1];
        undelegations.pop();
    }
}
