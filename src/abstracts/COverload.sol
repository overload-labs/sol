// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {IHOverload} from "../interfaces/IHOverload.sol";
import {HookCallLib} from "../libraries/HookCallLib.sol";
import {DelegationLib, Delegation, DelegationKey} from "../libraries/types/Delegation.sol";
import {UndelegationLib, Undelegation, UndelegationKey} from "../libraries/types/Undelegation.sol";

/// @notice The implementation of the Overload hook calls contract.
/// @dev This is the logic for how `Overload.sol` calls external contracts that implement the hook callbacks.
abstract contract COverload {
    /*//////////////////////////////////////////////////////////////
                                DELEGATE
    //////////////////////////////////////////////////////////////*/

    function _beforeDelegateHook(
        address target,
        uint256 gas,
        DelegationKey memory key,
        uint256 delta,
        bytes calldata data,
        bool strict
    ) internal {
        if (ERC165Checker.supportsInterface(target, IHOverload.beforeDelegate.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeCall(IHOverload.beforeDelegate, (msg.sender, key, delta, data)),
                strict
            );
        }
    }

    function _afterDelegateHook(
        address target,
        uint256 gas,
        DelegationKey memory key,
        uint256 delta,
        bytes calldata data,
        bool strict,
        Delegation memory delegation,
        uint256 index
    ) internal {
        if (ERC165Checker.supportsInterface(target, IHOverload.afterDelegate.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeCall(IHOverload.afterDelegate, (msg.sender, key, delta, data, delegation, index)),
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
        bytes calldata data,
        bool strict
    ) internal {
        if (ERC165Checker.supportsInterface(target, IHOverload.beforeRedelegate.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeCall(IHOverload.beforeRedelegate, (msg.sender, from, to, data)),
                strict
            );
        }
    }

    function _afterRedelegateHook(
        address target,
        uint256 gas,
        DelegationKey memory from,
        DelegationKey memory to,
        bytes calldata data,
        bool strict
    ) internal {
        if (ERC165Checker.supportsInterface(target, IHOverload.afterRedelegate.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeCall(IHOverload.afterRedelegate, (msg.sender, from, to, data)),
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
        uint256 delta,
        bytes calldata data,
        bool strict,
        uint256 index
    ) internal {
        if (ERC165Checker.supportsInterface(target, IHOverload.beforeUndelegating.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeCall(IHOverload.beforeUndelegating, (msg.sender, key, delta, data, index)),
                strict
            );
        }
    }

    function _afterUndelegatingHook(
        address target,
        uint256 gas,
        DelegationKey memory key,
        uint256 delta,
        bytes calldata data,
        bool strict,
        UndelegationKey memory ukey,
        uint256 index
    ) internal {
        if (ERC165Checker.supportsInterface(target, IHOverload.afterUndelegating.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeCall(IHOverload.afterUndelegating, (msg.sender, key, delta, data, ukey, index)),
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
        if (ERC165Checker.supportsInterface(target, IHOverload.beforeDelegate.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeCall(IHOverload.beforeUndelegate, (msg.sender, key, position, data, index)),
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
        if (ERC165Checker.supportsInterface(target, IHOverload.afterUndelegate.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeCall(IHOverload.afterUndelegate, (msg.sender, key, position, data)),
                strict
            );
        }
    }
}
