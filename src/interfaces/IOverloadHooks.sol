// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Delegation, DelegationKey} from "../libraries/types/Delegation.sol";
import {Validator} from "../libraries/types/Validator.sol";
import {Pool} from "../libraries/types/Pool.sol";

interface IOverloadHooks {
    function permissions() external view returns (uint256);

    function beforeDelegate(
        address sender,
        DelegationKey memory key,
        uint256 delta,
        bytes calldata data
    ) external returns (bytes4);

    function afterDelegate(
        address sender,
        DelegationKey memory key,
        uint256 delta,
        Delegation memory delegation,
        Validator memory validator,
        Pool memory pool,
        bytes calldata data
    ) external returns (bytes4);

    function beforeUndelegating(
        address sender,
        DelegationKey memory key,
        uint256 delta,
        bytes calldata data
    ) external returns (bytes4);

    function afterUndelegating(
        address sender,
        DelegationKey memory key,
        uint256 delta,
        Delegation memory delegation,
        Validator memory validator,
        Pool memory pool,
        bytes calldata data
    ) external returns (bytes4);
}
