// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {IOverloadHooks} from "../interfaces/IOverloadHooks.sol";
import {Hooks} from "../libraries/Hooks.sol";
import {DelegationLib, Delegation, DelegationKey} from "../libraries/types/Delegation.sol";
import {UndelegationLib, Undelegation, UndelegationKey} from "../libraries/types/Undelegation.sol";

abstract contract OverloadHooks {
    /*//////////////////////////////////////////////////////////////
                                DELEGATE
    //////////////////////////////////////////////////////////////*/

    function _beforeDelegateHook(
        address target,
        DelegationKey memory key,
        uint256 delta,
        bytes calldata data,
        bool strict
    ) internal {
        if (ERC165Checker.supportsInterface(target, IOverloadHooks.beforeDelegate.selector)) {
            Hooks.callHook(target, abi.encodeWithSelector(IOverloadHooks.beforeDelegate.selector, msg.sender, key, delta, data), strict);
        }
    }

    function _afterDelegateHook(
        address target,
        DelegationKey memory key,
        uint256 delta,
        Delegation memory delegation,
        bytes calldata data,
        bool strict
    ) internal {
        if (ERC165Checker.supportsInterface(target, IOverloadHooks.afterDelegate.selector)) {
            Hooks.callHook(
                target,
                abi.encodeWithSelector(
                    IOverloadHooks.afterDelegate.selector,
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
        DelegationKey memory from,
        DelegationKey memory to,
        bytes calldata data,
        bool strict
    ) internal {
        if (ERC165Checker.supportsInterface(target, IOverloadHooks.beforeRedelegate.selector)) {
            Hooks.callHook(target, abi.encodeWithSelector(IOverloadHooks.beforeRedelegate.selector, msg.sender, from, to, data), strict);
        }
    }

    function _afterRedelegateHook(
        address target,
        DelegationKey memory from,
        DelegationKey memory to,
        bytes calldata data,
        bool strict
    ) internal {
        if (ERC165Checker.supportsInterface(target, IOverloadHooks.afterRedelegate.selector)) {
            Hooks.callHook(target, abi.encodeWithSelector(IOverloadHooks.afterRedelegate.selector, msg.sender, from, to, data), strict);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              UNDELEGATING
    //////////////////////////////////////////////////////////////*/

    function _beforeUndelegatingHook(
        address target,
        DelegationKey memory key,
        uint256 delta,
        bytes calldata data
    ) internal {
        if (ERC165Checker.supportsInterface(target, IOverloadHooks.beforeUndelegating.selector)) {
            Hooks.callHook(target, abi.encodeWithSelector(IOverloadHooks.beforeUndelegating.selector, msg.sender, key, delta, data), false);
        }
    }

    function _afterUndelegatingHook(
        address target,
        DelegationKey memory key,
        uint256 delta,
        Delegation memory delegation,
        bytes calldata data
    ) internal {
        if (ERC165Checker.supportsInterface(target, IOverloadHooks.afterUndelegating.selector)) {
            Hooks.callHook(
                target,
                abi.encodeWithSelector(
                    IOverloadHooks.afterUndelegating.selector,
                    msg.sender,
                    key,
                    delta,
                    delegation,
                    data
                ),
                false
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                               UNDELEGATE
    //////////////////////////////////////////////////////////////*/

    function _beforeUndelegateHook(
        address target,
        UndelegationKey memory key,
        bytes calldata data
    ) internal {
        if (ERC165Checker.supportsInterface(target, IOverloadHooks.beforeDelegate.selector)) {
            Hooks.callHook(target, abi.encodeWithSelector(IOverloadHooks.beforeUndelegate.selector, msg.sender, key, data), false);
        }
    }

    function _afterUndelegateHook(
        address target,
        UndelegationKey memory key,
        bytes calldata data
    ) internal {
        if (ERC165Checker.supportsInterface(target, IOverloadHooks.afterUndelegate.selector)) {
            Hooks.callHook(target, abi.encodeWithSelector(IOverloadHooks.afterUndelegate.selector, msg.sender, key, data), false);
        }
    }
}
