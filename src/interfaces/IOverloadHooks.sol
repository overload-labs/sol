// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DelegationKey} from "../libraries/types/Delegation.sol";

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
        bytes calldata data
    ) external returns (bytes4);
}
