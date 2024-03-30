// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Cast} from "../Cast.sol";

struct Undelegation {
    address consensus;
    address validator;
    uint256 amount;

    uint256 completion; // a unix timestamp in seconds
}

struct UndelegationKey {
    address owner;
    address token;
    address consensus;
    address validator;
    uint256 amount;
    uint256 completion;
}

library UndelegationLib {
    function zeroKey() internal pure returns (UndelegationKey memory) {
        return UndelegationKey({
            owner: address(0),
            token: address(0),
            consensus: address(0),
            validator: address(0),
            amount: 0,
            completion: 0
        });
    }

    function zero() internal pure returns (Undelegation memory) {
        return Undelegation({
            consensus: address(0),
            validator: address(0),
            amount: 0,
            completion: 0
        });
    }

    function get(
        mapping(address owner => mapping(address token => Undelegation[])) storage map,
        UndelegationKey memory key,
        bool strict
    ) internal view returns (Undelegation memory delegation, int256 index) {
        int256 position_ = position(map, key);

        if (position_ >= 0) {
            index = position_;
            delegation = map[key.owner][key.token][Cast.u256(index)];
        } else {
            if (strict) {
                revert("Undelegation.get: NOT_FOUND");
            } else {
                index = -1;
                delegation = zero();
            }
        }
    }

    function find(
        mapping(address owner => mapping(address token => Undelegation[])) storage map,
        UndelegationKey memory key,
        bool strict
    ) internal view returns (Undelegation memory) {
        int256 index = position(map, key);

        if (index >= 0 && Cast.u256(index) < map[key.owner][key.token].length) {
            return map[key.owner][key.token][Cast.u256(index)]; 
        } else {
            if (strict) {
                revert("UNDELEGATION_NOT_FOUND");
            } else {
                return zero();
            }
        }
    }

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
                key.completion == undelegation.completion
            ) {
                return int256(i);
            }
        }

        return -1;
    }

    function add(
        mapping(address owner => mapping(address token => Undelegation[])) storage map,
        UndelegationKey memory key
    ) internal {
        map[key.owner][key.token].push(Undelegation({
            consensus: key.consensus,
            validator: key.validator,
            amount: key.amount,
            completion: key.completion
        }));
    }

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
        require(removed.completion == removed.completion);

        undelegations[index] = undelegations[undelegations.length - 1];
        undelegations.pop();
    }
}
