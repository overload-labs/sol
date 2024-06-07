// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DelegationKey, Delegation} from "../../src/libraries/types/Delegation.sol";
import {UndelegationKey, Undelegation} from "../../src/libraries/types/Undelegation.sol";
import {IHOverload} from "../../src/interfaces/IHOverload.sol";

contract ConsensusBeforeDelegateMock {
    // Core contract
    address public overload;

    constructor(address overload_) {
        overload = overload_;
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == IHOverload.beforeDelegate.selector ||
            interfaceId == IHOverload.beforeUndelegating.selector;
    }
}

contract ConsensusRevertAllMock is IHOverload {
    // Core contract
    address public overload;

    constructor(address overload_) {
        overload = overload_;
    }

    function beforeDelegate(address, DelegationKey memory, uint256, bytes calldata) external pure returns (bytes4) {
        revert();
    }

    function afterDelegate(address, DelegationKey memory, uint256, Delegation memory, bytes calldata) external pure returns (bytes4) {
        revert();
    }

    function beforeRedelegate(address, DelegationKey memory, uint256, bytes calldata) external pure returns (bytes4) {
        revert();
    }

    function afterRedelegate(address, DelegationKey memory, uint256, Delegation memory, bytes calldata) external pure returns (bytes4) {
        revert();
    }

    function beforeUndelegating(address, DelegationKey memory, uint256, bytes calldata) external pure returns (bytes4) {
        revert();
    }

    function afterUndelegating(address, DelegationKey memory, uint256, Delegation memory, bytes calldata) external pure returns (bytes4) {
        revert();
    }

    function beforeUndelegate(address, UndelegationKey memory, bytes calldata) external pure returns (bytes4) {
        revert();
    }

    function afterUndelegate(address, UndelegationKey memory, bytes calldata) external pure returns (bytes4) {
        revert();
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == IHOverload.beforeDelegate.selector ||
            interfaceId == IHOverload.afterDelegate.selector ||
            interfaceId == IHOverload.beforeRedelegate.selector ||
            interfaceId == IHOverload.afterRedelegate.selector ||
            interfaceId == IHOverload.beforeUndelegating.selector ||
            interfaceId == IHOverload.afterUndelegating.selector ||
            interfaceId == IHOverload.beforeUndelegate.selector ||
            interfaceId == IHOverload.afterUndelegate.selector;
    }
}
