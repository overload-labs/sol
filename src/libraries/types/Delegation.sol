// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Cast} from "../Cast.sol";

struct Delegation {
    address consensus;
    address validator;
    uint256 amount;
}

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

    function zero() internal pure returns (Delegation memory) {
        return Delegation({
            consensus: address(0),
            validator: address(0),
            amount: 0
        });
    }

    function get(
        mapping(address owner => mapping(address token => Delegation[])) storage map,
        DelegationKey memory key,
        bool strict
    ) internal view returns (Delegation memory delegation, int256 index) {
        int256 position_ = position(map, key);

        if (position_ >= 0) {
            index = position_;
            delegation = map[key.owner][key.token][Cast.u256(index)];
        } else {
            if (strict) {
                revert("Delegation.get: NOT_FOUND");
            } else {
                index = -1;
                delegation = zero();
            }
        }
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

    function find(
        mapping(address owner => mapping(address token => Delegation[])) storage map,
        DelegationKey memory key,
        bool strict
    ) internal view returns (Delegation memory) {
        int256 index = position(map, key);

        if (index >= 0 && Cast.u256(index) < map[key.owner][key.token].length) {
            return map[key.owner][key.token][Cast.u256(index)]; 
        } else {
            if (strict) {
                revert("DELEGATION_NOT_FOUND");
            } else {
                return zero();
            }
        }
    }

    function position(
        mapping(address owner => mapping(address token => Delegation[])) storage map,
        DelegationKey memory key
    ) internal view returns (int256) {
        for (uint256 i = 0; i < map[key.owner][key.token].length; i++) {
            Delegation memory delegation = map[key.owner][key.token][i];

            if (key.consensus == delegation.consensus && key.validator == delegation.validator) {
                return int256(i);
            }
        }

        return -1;
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
