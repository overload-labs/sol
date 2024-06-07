// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CastLib} from "../CastLib.sol";

error DelegationNotFound();

/// @dev `Delegation` objects are unique. There cannot be duplicates inside the mapping.
struct Delegation {
    address consensus;
    address validator;
    uint256 amount;
}

/// @dev `DelegationKey`s are used to identify the unique Delegation objects.
struct DelegationKey {
    address owner;
    address token;
    address consensus;
    address validator;
}

library DelegationLib {
    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

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

    function position(
        mapping(address owner => mapping(address token => Delegation[])) storage map,
        DelegationKey memory key
    ) internal view returns (int256) {
        Delegation[] memory delegations = map[key.owner][key.token];

        for (uint256 i = 0; i < delegations.length; i++) {
            Delegation memory delegation = delegations[i];

            if (key.consensus == delegation.consensus && key.validator == delegation.validator) {
                return int256(i);
            }
        }

        return -1;
    }

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

    function push(
        mapping(address owner => mapping(address token => Delegation[])) storage map,
        DelegationKey memory key,
        uint256 amount
    ) internal returns (Delegation memory delegation) {
        map[key.owner][key.token].push(
            delegation = Delegation({
                consensus: key.consensus,
                validator: key.validator,
                amount: amount
            })
        );
    }

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
