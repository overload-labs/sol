// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {IHOverload} from "../interfaces/IHOverload.sol";
import {HooksLib} from "../libraries/HooksLib.sol";
import {DelegationLib, Delegation, DelegationKey} from "../libraries/types/Delegation.sol";
import {UndelegationLib, Undelegation, UndelegationKey} from "../libraries/types/Undelegation.sol";

abstract contract HOverload {
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
        if (ERC165Checker.supportsInterface(target, IHOverload.beforeDelegate.selector)) {
            HooksLib.callHook(target, abi.encodeWithSelector(IHOverload.beforeDelegate.selector, msg.sender, key, delta, data), strict);
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
        if (ERC165Checker.supportsInterface(target, IHOverload.afterDelegate.selector)) {
            HooksLib.callHook(
                target,
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
        DelegationKey memory from,
        DelegationKey memory to,
        bytes calldata data,
        bool strict
    ) internal {
        if (ERC165Checker.supportsInterface(target, IHOverload.beforeRedelegate.selector)) {
            HooksLib.callHook(target, abi.encodeWithSelector(IHOverload.beforeRedelegate.selector, msg.sender, from, to, data), strict);
        }
    }

    function _afterRedelegateHook(
        address target,
        DelegationKey memory from,
        DelegationKey memory to,
        bytes calldata data,
        bool strict
    ) internal {
        if (ERC165Checker.supportsInterface(target, IHOverload.afterRedelegate.selector)) {
            HooksLib.callHook(target, abi.encodeWithSelector(IHOverload.afterRedelegate.selector, msg.sender, from, to, data), strict);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              UNDELEGATING
    //////////////////////////////////////////////////////////////*/

    function _beforeUndelegatingHook(
        address target,
        DelegationKey memory key,
        uint256 delta,
        bytes calldata data,
        bool strict
    ) internal {
        if (ERC165Checker.supportsInterface(target, IHOverload.beforeUndelegating.selector)) {
            HooksLib.callHook(target, abi.encodeWithSelector(IHOverload.beforeUndelegating.selector, msg.sender, key, delta, data), strict);
        }
    }

    function _afterUndelegatingHook(
        address target,
        DelegationKey memory key,
        uint256 delta,
        Delegation memory delegation,
        bytes calldata data,
        bool strict
    ) internal {
        if (ERC165Checker.supportsInterface(target, IHOverload.afterUndelegating.selector)) {
            HooksLib.callHook(
                target,
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
        UndelegationKey memory key,
        bytes calldata data
    ) internal {
        if (ERC165Checker.supportsInterface(target, IHOverload.beforeDelegate.selector)) {
            HooksLib.callHook(target, abi.encodeWithSelector(IHOverload.beforeUndelegate.selector, msg.sender, key, data), false);
        }
    }

    function _afterUndelegateHook(
        address target,
        UndelegationKey memory key,
        bytes calldata data
    ) internal {
        if (ERC165Checker.supportsInterface(target, IHOverload.afterUndelegate.selector)) {
            HooksLib.callHook(target, abi.encodeWithSelector(IHOverload.afterUndelegate.selector, msg.sender, key, data), false);
        }
    }
}
