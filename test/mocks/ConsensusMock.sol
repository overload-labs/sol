// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DelegationKey, Delegation} from "../../src/libraries/types/Delegation.sol";
import {UndelegationKey, Undelegation} from "../../src/libraries/types/Undelegation.sol";
import {IHOverload} from "../../src/interfaces/IHOverload.sol";

contract ConsensusHookParametersMock is IHOverload {
    address public overload;
    address public token;

    constructor(address overload_, address token_) {
        overload = overload_;
        token = token_;
    }

    function beforeDelegate(address sender, DelegationKey memory key, uint256 delta, bytes calldata data) public view returns (bytes4) {
        require(sender == address(0xBEEF));
        require(key.owner == address(0xBEEF));
        require(key.token == address(token));
        require(key.consensus == address(this));
        require(key.validator == address(0xFFFF));
        require(delta == 100);
        require(keccak256(data) == keccak256(hex"42"));

        return IHOverload.beforeDelegate.selector;
    }

    function afterDelegate(address sender, DelegationKey memory key, uint256 delta, Delegation memory delegation, bytes calldata data) public view returns (bytes4) {
        require(sender == address(0xBEEF));
        require(key.owner == address(0xBEEF));
        require(key.token == address(token));
        require(key.consensus == address(this));
        require(key.validator == address(0xFFFF));
        require(delta == 100);
        require(delegation.consensus == address(this));
        require(delegation.validator == address(0xFFFF));
        require(delegation.amount == 100);
        require(keccak256(data) == keccak256(hex"42"));

        return IHOverload.afterDelegate.selector;
    }

    function beforeRedelegate(address sender, DelegationKey memory from, DelegationKey memory to, bytes calldata data) public view returns (bytes4) {
        require(sender == address(0xBEEF));
        require(from.owner == address(0xBEEF));
        require(from.token == address(token));
        require(from.consensus == address(this));
        require(from.validator == address(0xFFFF));
        require(to.owner == address(0xBEEF));
        require(to.token == address(token));
        require(to.consensus == address(this));
        require(to.validator == address(0xEEEE));
        require(keccak256(data) == keccak256(hex"42"));

        return IHOverload.beforeRedelegate.selector;
    }

    function afterRedelegate(address sender, DelegationKey memory from, DelegationKey memory to, bytes calldata data) public view returns (bytes4) {
        require(sender == address(0xBEEF));
        require(from.owner == address(0xBEEF));
        require(from.token == address(token));
        require(from.consensus == address(this));
        require(from.validator == address(0xFFFF));
        require(to.owner == address(0xBEEF));
        require(to.token == address(token));
        require(to.consensus == address(this));
        require(to.validator == address(0xEEEE));
        require(keccak256(data) == keccak256(hex"42"));

        return IHOverload.afterRedelegate.selector;
    }

    function beforeUndelegating(address sender, DelegationKey memory key, uint256 delta, bytes calldata data) public view returns (bytes4) {
        require(sender == address(0xBEEF));
        require(key.owner == address(0xBEEF));
        require(key.token == address(token));
        require(key.consensus == address(this));
        require(key.validator == address(0xEEEE));
        require(delta == 100);
        require(keccak256(data) == keccak256(hex"42"));

        return IHOverload.beforeUndelegating.selector;
    }

    function afterUndelegating(address sender, DelegationKey memory key, uint256 delta, UndelegationKey memory ukey, bytes calldata data) public view returns (bytes4) {
        require(sender == address(0xBEEF));
        require(key.owner == address(0xBEEF));
        require(key.token == address(token));
        require(key.consensus == address(this));
        require(key.validator == address(0xEEEE));
        require(delta == 100);
        require(ukey.owner == address(0xBEEF));
        require(ukey.token == address(token));
        require(ukey.consensus == address(this));
        require(ukey.validator == address(0xEEEE));
        require(ukey.amount == 100);
        require(ukey.maturity == 501);
        require(keccak256(data) == keccak256(hex"42"));

        return IHOverload.afterUndelegating.selector;
    }

    function beforeUndelegate(address sender, UndelegationKey memory ukey, int256 position, bytes calldata data) public view returns (bytes4) {
        require(sender == address(0xBEEF));
        require(ukey.owner == address(0xBEEF));
        require(ukey.token == address(token));
        require(ukey.consensus == address(this));
        require(ukey.validator == address(0xEEEE));
        require(ukey.amount == 100);
        require(ukey.maturity == 501);
        require(position == -1);
        require(keccak256(data) == keccak256(hex"42"));

        return IHOverload.beforeUndelegate.selector;
    }

    function afterUndelegate(address sender, UndelegationKey memory ukey, int256 position, bytes calldata data) public view returns (bytes4) {
        require(sender == address(0xBEEF));
        require(ukey.owner == address(0xBEEF));
        require(ukey.token == address(token));
        require(ukey.consensus == address(this));
        require(ukey.validator == address(0xEEEE));
        require(ukey.amount == 100);
        require(ukey.maturity == 501);
        require(position == -1);
        require(keccak256(data) == keccak256(hex"42"));

        return IHOverload.afterUndelegate.selector;
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

    function test() public {}
}

contract ConsensusRevertDelegateMock is IHOverload {
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

    function beforeRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata) public returns (bytes4) {}

    function afterRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata) public returns (bytes4) {}

    function beforeUndelegating(address, DelegationKey memory, uint256, bytes calldata) external pure returns (bytes4) {}

    function afterUndelegating(address, DelegationKey memory, uint256, UndelegationKey memory, bytes calldata) external pure returns (bytes4) {}

    function beforeUndelegate(address, UndelegationKey memory, int256, bytes calldata) external pure returns (bytes4) {}

    function afterUndelegate(address, UndelegationKey memory, int256, bytes calldata) external pure returns (bytes4) {}

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == IHOverload.beforeDelegate.selector ||
            interfaceId == IHOverload.afterDelegate.selector;
    }

    function test() public {}
}

contract ConsensusRevertRedelegateMock is IHOverload {
    address public overload;

    constructor(address overload_) {
        overload = overload_;
    }

    function beforeDelegate(address, DelegationKey memory, uint256, bytes calldata) external pure returns (bytes4) {}

    function afterDelegate(address, DelegationKey memory, uint256, Delegation memory, bytes calldata) external pure returns (bytes4) {}

    function beforeRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata) public returns (bytes4) {
        revert();
    }

    function afterRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata) public returns (bytes4) {
        revert();
    }

    function beforeUndelegating(address, DelegationKey memory, uint256, bytes calldata) external pure returns (bytes4) {}

    function afterUndelegating(address, DelegationKey memory, uint256, UndelegationKey memory, bytes calldata) external pure returns (bytes4) {}

    function beforeUndelegate(address, UndelegationKey memory, int256 position, bytes calldata) external pure returns (bytes4) {}

    function afterUndelegate(address, UndelegationKey memory, int256 position, bytes calldata) external pure returns (bytes4) {}

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == IHOverload.beforeRedelegate.selector ||
            interfaceId == IHOverload.afterRedelegate.selector;
    }

    function test() public {}
}

contract ConsensusRevertUndelegatingMock is IHOverload {
    address public overload;

    constructor(address overload_) {
        overload = overload_;
    }

    function beforeDelegate(address, DelegationKey memory, uint256, bytes calldata) external pure returns (bytes4) {}

    function afterDelegate(address, DelegationKey memory, uint256, Delegation memory, bytes calldata) external pure returns (bytes4) {}

    function beforeRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata) public returns (bytes4) {}

    function afterRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata) public returns (bytes4) {}

    function beforeUndelegating(address, DelegationKey memory, uint256, bytes calldata) external pure returns (bytes4) {
        revert();
    }

    function afterUndelegating(address, DelegationKey memory, uint256, UndelegationKey memory, bytes calldata) external pure returns (bytes4) {
        revert();
    }

    function beforeUndelegate(address, UndelegationKey memory, int256, bytes calldata) external pure returns (bytes4) {}

    function afterUndelegate(address, UndelegationKey memory, int256, bytes calldata) external pure returns (bytes4) {}

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == IHOverload.beforeUndelegating.selector ||
            interfaceId == IHOverload.afterUndelegating.selector;
    }

    function test() public {}
}

contract ConsensusRevertUndelegateMock is IHOverload {
    address public overload;

    constructor(address overload_) {
        overload = overload_;
    }

    function beforeDelegate(address, DelegationKey memory, uint256, bytes calldata) external pure returns (bytes4) {}

    function afterDelegate(address, DelegationKey memory, uint256, Delegation memory, bytes calldata) external pure returns (bytes4) {}

    function beforeRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata) public returns (bytes4) {}

    function afterRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata) public returns (bytes4) {}

    function beforeUndelegating(address, DelegationKey memory, uint256, bytes calldata) external pure returns (bytes4) {}

    function afterUndelegating(address, DelegationKey memory, uint256, UndelegationKey memory, bytes calldata) external pure returns (bytes4) {}

    function beforeUndelegate(address, UndelegationKey memory, int256, bytes calldata) external pure returns (bytes4) {
        revert();
    }

    function afterUndelegate(address, UndelegationKey memory, int256, bytes calldata) external pure returns (bytes4) {
        revert();
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == IHOverload.beforeUndelegate.selector ||
            interfaceId == IHOverload.afterUndelegate.selector;
    }

    function test() public {}
}

contract ConsensusNoHook {
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
