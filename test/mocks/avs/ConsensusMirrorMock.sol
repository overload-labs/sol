// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IHOverload} from "../../../src/interfaces/IHOverload.sol";
import {Delegation, DelegationKey} from "../../../src/libraries/types/Delegation.sol";
import {Overload} from "../../../src/Overload.sol";

import {CheckpointLib, Checkpoint} from "./Checkpoint.sol";

/// @notice An example AVS
contract ConsensusMirror {
    using CheckpointLib for Checkpoint[];

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    // Core contract
    address public overload;

    mapping(address owner => mapping(address token => Checkpoint[])) public balances;
    mapping(address validator => mapping(address token => Checkpoint[])) public validators;
    mapping(address token => Checkpoint[]) public pools;

    constructor(address overload_) {
        overload = overload_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    function getBalance(address owner, address token) public view returns (uint256) {
        return balances[owner][token].head().amount;
    }

    function getValidator(address validator, address token) public view returns (uint256) {
        return validators[validator][token].head().amount;
    }

    function getPool(address token) public view returns (uint256) {
        return pools[token].head().amount;
    }

    /*//////////////////////////////////////////////////////////////
                                 ADMIN
    //////////////////////////////////////////////////////////////*/

    /**
     * Overload Admin
     */

    function setUndelegatingDelay(uint256 delay) public {
        Overload(overload).setUndelegatingDelay(address(this), delay);
    }

    /*//////////////////////////////////////////////////////////////
                                METHODS
    //////////////////////////////////////////////////////////////*/

    function jail(address validator, uint256 time) public {
        Overload(overload).jail(validator, time);
    }

    /*//////////////////////////////////////////////////////////////
                                 HOOKS
    //////////////////////////////////////////////////////////////*/

    function beforeDelegate(address, DelegationKey memory key, uint256 delta, bytes calldata, bool strict) external returns (bytes4) {
        require(msg.sender == overload);
        require(strict == true);

        balances[key.owner][key.token].increase(delta);
        validators[key.validator][key.token].increase(delta);
        pools[key.token].increase(delta);

        return IHOverload.beforeDelegate.selector;
    }

    function beforeUndelegating(address, DelegationKey memory key, uint256 delta, bytes calldata, bool, uint256) external returns (bytes4) {
        require(msg.sender == overload);

        balances[key.owner][key.token].decrease(delta);
        validators[key.validator][key.token].decrease(delta);
        pools[key.token].decrease(delta);

        return IHOverload.beforeUndelegating.selector;
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == IHOverload.beforeDelegate.selector ||
            interfaceId == IHOverload.beforeUndelegating.selector;
    }

    function test() public {}
}
