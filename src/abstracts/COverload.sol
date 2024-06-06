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
            HookCallLib.functionCallHook(target, gas, abi.encodeWithSelector(IHOverload.beforeDelegate.selector, msg.sender, key, delta, data), strict);
        }
    }

    function _afterDelegateHook(
        address target,
        uint256 gas,
        DelegationKey memory key,
        uint256 delta,
        Delegation memory delegation,
        bytes calldata data,
        bool strict
    ) internal {
        if (ERC165Checker.supportsInterface(target, IHOverload.afterDelegate.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeWithSelector(
                    IHOverload.afterDelegate.selector,
                    msg.sender,
                    key,
                    delta,
                    delegation,
                    data
                ),
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
            HookCallLib.functionCallHook(target, gas, abi.encodeWithSelector(IHOverload.beforeRedelegate.selector, msg.sender, from, to, data), strict);
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
            HookCallLib.functionCallHook(target, gas, abi.encodeWithSelector(IHOverload.afterRedelegate.selector, msg.sender, from, to, data), strict);
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
        bool strict
    ) internal {
        if (ERC165Checker.supportsInterface(target, IHOverload.beforeUndelegating.selector)) {
            HookCallLib.functionCallHook(target, gas, abi.encodeWithSelector(IHOverload.beforeUndelegating.selector, msg.sender, key, delta, data), strict);
        }
    }

    function _afterUndelegatingHook(
        address target,
        uint256 gas,
        DelegationKey memory key,
        uint256 delta,
        Delegation memory delegation,
        bytes calldata data,
        bool strict
    ) internal {
        if (ERC165Checker.supportsInterface(target, IHOverload.afterUndelegating.selector)) {
            HookCallLib.functionCallHook(
                target,
                gas,
                abi.encodeWithSelector(
                    IHOverload.afterUndelegating.selector,
                    msg.sender,
                    key,
                    delta,
                    delegation,
                    data
                ),
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
        bytes calldata data
    ) internal {
        if (ERC165Checker.supportsInterface(target, IHOverload.beforeDelegate.selector)) {
            HookCallLib.functionCallHook(target, gas, abi.encodeWithSelector(IHOverload.beforeUndelegate.selector, msg.sender, key, data), false);
        }
    }

    function _afterUndelegateHook(
        address target,
        uint256 gas,
        UndelegationKey memory key,
        bytes calldata data
    ) internal {
        if (ERC165Checker.supportsInterface(target, IHOverload.afterUndelegate.selector)) {
            HookCallLib.functionCallHook(target, gas, abi.encodeWithSelector(IHOverload.afterUndelegate.selector, msg.sender, key, data), false);
        }
    }
}
