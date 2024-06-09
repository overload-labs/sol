// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {HOverload} from "../interfaces/HOverload.sol";
import {HookCallLib} from "../libraries/HookCallLib.sol";
import {DelegationLib, Delegation, DelegationKey} from "../libraries/types/Delegation.sol";
import {UndelegationLib, Undelegation, UndelegationKey} from "../libraries/types/Undelegation.sol";

/// @title COverload (Overload Calls)
/// @notice The implementation of the Overload calls contract.
/// @dev The logic for how the `Overload.sol` calls contracts that implement the hooks from `HOverload.sol`.
abstract contract COverload {
    /*//////////////////////////////////////////////////////////////
                                DELEGATE
    //////////////////////////////////////////////////////////////*/

    function _beforeDelegateHook(
        address target,
        uint256 gas,
        DelegationKey memory key,
        int256 position,
        uint256 delta,
        bytes calldata data,
        bool strict
    ) internal {
        if (ERC165Checker.supportsInterface(target, HOverload.beforeDelegate.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeCall(HOverload.beforeDelegate, (msg.sender, key, position, delta, data, strict)),
                strict
            );
        }
    }

    function _afterDelegateHook(
        address target,
        uint256 gas,
        DelegationKey memory key,
        int256 position,
        uint256 delta,
        bytes calldata data,
        bool strict,
        Delegation memory delegation,
        uint256 index
    ) internal {
        if (ERC165Checker.supportsInterface(target, HOverload.afterDelegate.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeCall(HOverload.afterDelegate, (msg.sender, key, position, delta, data, strict, delegation, index)),
                strict
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                               REDELEGATE
    //////////////////////////////////////////////////////////////*/

    function _beforeRedelegateHook(
        address target,
        uint256 gas,
        DelegationKey memory from,
        DelegationKey memory to,
        int256 position,
        bytes calldata data,
        bool strict
    ) internal {
        if (ERC165Checker.supportsInterface(target, HOverload.beforeRedelegate.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeCall(HOverload.beforeRedelegate, (msg.sender, from, to, position, data, strict)),
                strict
            );
        }
    }

    function _afterRedelegateHook(
        address target,
        uint256 gas,
        DelegationKey memory from,
        DelegationKey memory to,
        int256 position,
        bytes calldata data,
        bool strict,
        uint256 index
    ) internal {
        if (ERC165Checker.supportsInterface(target, HOverload.afterRedelegate.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeCall(HOverload.afterRedelegate, (msg.sender, from, to, position, data, strict, index)),
                strict
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                              UNDELEGATING
    //////////////////////////////////////////////////////////////*/

    function _beforeUndelegatingHook(
        address target,
        uint256 gas,
        DelegationKey memory key,
        int256 position,
        uint256 delta,
        bytes calldata data,
        bool strict,
        uint256 index
    ) internal {
        if (ERC165Checker.supportsInterface(target, HOverload.beforeUndelegating.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeCall(HOverload.beforeUndelegating, (msg.sender, key, position, delta, data, strict, index)),
                strict
            );
        }
    }

    function _afterUndelegatingHook(
        address target,
        uint256 gas,
        DelegationKey memory key,
        int256 position,
        uint256 delta,
        bytes calldata data,
        bool strict,
        UndelegationKey memory ukey,
        int256 index
    ) internal {
        if (ERC165Checker.supportsInterface(target, HOverload.afterUndelegating.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeCall(HOverload.afterUndelegating, (msg.sender, key, position, delta, data, strict, ukey, index)),
                strict
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                               UNDELEGATE
    //////////////////////////////////////////////////////////////*/

    function _beforeUndelegateHook(
        address target,
        uint256 gas,
        UndelegationKey memory key,
        int256 position,
        bytes calldata data,
        bool strict,
        uint256 index
    ) internal {
        if (ERC165Checker.supportsInterface(target, HOverload.beforeDelegate.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeCall(HOverload.beforeUndelegate, (msg.sender, key, position, data, strict, index)),
                strict
            );
        }
    }

    function _afterUndelegateHook(
        address target,
        uint256 gas,
        UndelegationKey memory key,
        int256 position,
        bytes calldata data,
        bool strict
    ) internal {
        if (ERC165Checker.supportsInterface(target, HOverload.afterUndelegate.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeCall(HOverload.afterUndelegate, (msg.sender, key, position, data, strict)),
                strict
            );
        }
    }
}
