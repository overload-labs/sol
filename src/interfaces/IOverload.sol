// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DelegationKey} from "../libraries/types/Delegation.sol";
import {UndelegationKey} from "../libraries/types/Undelegation.sol";

interface IOverload {
    function setUndelegatingDelay(address consensus, uint256 delay) external returns (bool);
    function deposit(address owner, address token, uint256 amount) external returns (bool);
    function withdraw(address owner, address token, uint256 amount, address recipient) external returns (bool);
    function delegate(DelegationKey memory key, uint256 delta, bytes calldata data, bool strict) external returns (bool);
    function redelegate(DelegationKey memory from, DelegationKey memory to, bytes calldata data) external returns (bool);
    function undelegating(DelegationKey memory key, uint256 delta, bytes calldata data, bool strict) external returns (bool, UndelegationKey memory);
    function undelegate(UndelegationKey memory key, int256 position, bytes calldata data) external returns (bool);
    function jail(address validator, uint256 jailtime) external returns (bool);
}
