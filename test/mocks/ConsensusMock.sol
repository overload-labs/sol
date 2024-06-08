// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DelegationKey, Delegation} from "../../src/libraries/types/Delegation.sol";
import {UndelegationKey, Undelegation} from "../../src/libraries/types/Undelegation.sol";
import {HOverload} from "../../src/interfaces/HOverload.sol";

contract ConsensusHookParametersMock is HOverload {
    address public overload;
    address public token;

    constructor(address overload_, address token_) {
        overload = overload_;
        token = token_;
    }

    function beforeDelegate(address sender, DelegationKey memory key, uint256 delta, bytes calldata data, bool strict) public view returns (bytes4) {
        require(sender == address(0xBEEF));
        require(key.owner == address(0xBEEF));
        require(key.token == address(token));
        require(key.consensus == address(this));
        require(key.validator == address(0xFFFF));
        require(delta == 100);
        require(keccak256(data) == keccak256(hex"42"));
        require(strict == true);

        return HOverload.beforeDelegate.selector;
    }

    function afterDelegate(address sender, DelegationKey memory key, uint256 delta, bytes calldata data, bool strict, Delegation memory delegation, uint256 index) public view returns (bytes4) {
        require(sender == address(0xBEEF));
        require(key.owner == address(0xBEEF));
        require(key.token == address(token));
        require(key.consensus == address(this));
        require(key.validator == address(0xFFFF));
        require(delta == 100);
        require(keccak256(data) == keccak256(hex"42"));
        require(strict == true);
        require(delegation.consensus == address(this));
        require(delegation.validator == address(0xFFFF));
        require(delegation.amount == 100);
        require(index == 0);

        return HOverload.afterDelegate.selector;
    }

    function beforeRedelegate(address sender, DelegationKey memory from, DelegationKey memory to, bytes calldata data, bool strict) public view returns (bytes4) {
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
        require(strict == true);

        return HOverload.beforeRedelegate.selector;
    }

    function afterRedelegate(address sender, DelegationKey memory from, DelegationKey memory to, bytes calldata data, bool strict) public view returns (bytes4) {
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
        require(strict == true);

        return HOverload.afterRedelegate.selector;
    }

    function beforeUndelegating(address sender, DelegationKey memory key, uint256 delta, bytes calldata data, bool strict, uint256 index) public view returns (bytes4) {
        require(sender == address(0xBEEF));
        require(key.owner == address(0xBEEF));
        require(key.token == address(token));
        require(key.consensus == address(this));
        require(key.validator == address(0xEEEE));
        require(delta == 100);
        require(keccak256(data) == keccak256(hex"42"));
        require(strict == true);
        require(index == 0);

        return HOverload.beforeUndelegating.selector;
    }

    function afterUndelegating(address sender, DelegationKey memory key, uint256 delta, bytes calldata data, bool strict, UndelegationKey memory ukey, uint256 index) public view returns (bytes4) {
        require(sender == address(0xBEEF));
        require(key.owner == address(0xBEEF));
        require(key.token == address(token));
        require(key.consensus == address(this));
        require(key.validator == address(0xEEEE));
        require(delta == 100);
        require(keccak256(data) == keccak256(hex"42"));
        require(strict == true);
        require(ukey.owner == address(0xBEEF));
        require(ukey.token == address(token));
        require(ukey.consensus == address(this));
        require(ukey.validator == address(0xEEEE));
        require(ukey.amount == 100);
        require(ukey.maturity == 501);
        require(index == 0);

        return HOverload.afterUndelegating.selector;
    }

    function beforeUndelegate(address sender, UndelegationKey memory ukey, int256 position, bytes calldata data, bool strict, uint256 index) public view returns (bytes4) {
        require(sender == address(0xBEEF));
        require(ukey.owner == address(0xBEEF));
        require(ukey.token == address(token));
        require(ukey.consensus == address(this));
        require(ukey.validator == address(0xEEEE));
        require(ukey.amount == 100);
        require(ukey.maturity == 501);
        require(position == -1);
        require(keccak256(data) == keccak256(hex"42"));
        require(strict == true);
        require(index == 0);

        return HOverload.beforeUndelegate.selector;
    }

    function afterUndelegate(address sender, UndelegationKey memory ukey, int256 position, bytes calldata data, bool strict) public view returns (bytes4) {
        require(sender == address(0xBEEF));
        require(ukey.owner == address(0xBEEF));
        require(ukey.token == address(token));
        require(ukey.consensus == address(this));
        require(ukey.validator == address(0xEEEE));
        require(ukey.amount == 100);
        require(ukey.maturity == 501);
        require(position == -1);
        require(keccak256(data) == keccak256(hex"42"));
        require(strict == true);

        return HOverload.afterUndelegate.selector;
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == HOverload.beforeDelegate.selector ||
            interfaceId == HOverload.afterDelegate.selector ||
            interfaceId == HOverload.beforeRedelegate.selector ||
            interfaceId == HOverload.afterRedelegate.selector ||
            interfaceId == HOverload.beforeUndelegating.selector ||
            interfaceId == HOverload.afterUndelegating.selector ||
            interfaceId == HOverload.beforeUndelegate.selector ||
            interfaceId == HOverload.afterUndelegate.selector;
    }

    function test() public {}
}

contract ConsensusRevertDelegateMock is HOverload {
    address public overload;

    constructor(address overload_) {
        overload = overload_;
    }

    function beforeDelegate(address, DelegationKey memory, uint256, bytes calldata, bool) external pure returns (bytes4) {
        revert();
    }

    function afterDelegate(address, DelegationKey memory, uint256, bytes calldata, bool, Delegation memory, uint256) external pure returns (bytes4) {
        revert();
    }

    function beforeRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata, bool) public pure returns (bytes4) {}

    function afterRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata, bool) public pure returns (bytes4) {}

    function beforeUndelegating(address, DelegationKey memory, uint256, bytes calldata, bool, uint256) external pure returns (bytes4) {}

    function afterUndelegating(address, DelegationKey memory, uint256, bytes calldata, bool, UndelegationKey memory, uint256) external pure returns (bytes4) {}

    function beforeUndelegate(address, UndelegationKey memory, int256, bytes calldata, bool, uint256) external pure returns (bytes4) {}

    function afterUndelegate(address, UndelegationKey memory, int256, bytes calldata, bool) external pure returns (bytes4) {}

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == HOverload.beforeDelegate.selector ||
            interfaceId == HOverload.afterDelegate.selector;
    }

    function test() public {}
}

contract ConsensusRevertRedelegateMock is HOverload {
    address public overload;

    constructor(address overload_) {
        overload = overload_;
    }

    function beforeDelegate(address, DelegationKey memory, uint256, bytes calldata, bool) external pure returns (bytes4) {}

    function afterDelegate(address, DelegationKey memory, uint256, bytes calldata, bool, Delegation memory, uint256) external pure returns (bytes4) {}

    function beforeRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata, bool) public pure returns (bytes4) {
        revert();
    }

    function afterRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata, bool) public pure returns (bytes4) {
        revert();
    }

    function beforeUndelegating(address, DelegationKey memory, uint256, bytes calldata, bool, uint256) external pure returns (bytes4) {}

    function afterUndelegating(address, DelegationKey memory, uint256, bytes calldata, bool, UndelegationKey memory, uint256) external pure returns (bytes4) {}

    function beforeUndelegate(address, UndelegationKey memory, int256 position, bytes calldata, bool, uint256) external pure returns (bytes4) {}

    function afterUndelegate(address, UndelegationKey memory, int256 position, bytes calldata, bool) external pure returns (bytes4) {}

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == HOverload.beforeRedelegate.selector ||
            interfaceId == HOverload.afterRedelegate.selector;
    }

    function test() public {}
}

contract ConsensusRevertUndelegatingMock is HOverload {
    address public overload;

    constructor(address overload_) {
        overload = overload_;
    }

    function beforeDelegate(address, DelegationKey memory, uint256, bytes calldata, bool) external pure returns (bytes4) {}

    function afterDelegate(address, DelegationKey memory, uint256, bytes calldata, bool, Delegation memory, uint256) external pure returns (bytes4) {}

    function beforeRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata, bool) public pure returns (bytes4) {}

    function afterRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata, bool) public pure returns (bytes4) {}

    function beforeUndelegating(address, DelegationKey memory, uint256, bytes calldata, bool, uint256) external pure returns (bytes4) {
        revert();
    }

    function afterUndelegating(address, DelegationKey memory, uint256, bytes calldata, bool, UndelegationKey memory, uint256) external pure returns (bytes4) {
        revert();
    }

    function beforeUndelegate(address, UndelegationKey memory, int256, bytes calldata, bool, uint256) external pure returns (bytes4) {}

    function afterUndelegate(address, UndelegationKey memory, int256, bytes calldata, bool) external pure returns (bytes4) {}

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == HOverload.beforeUndelegating.selector ||
            interfaceId == HOverload.afterUndelegating.selector;
    }

    function test() public {}
}

contract ConsensusRevertUndelegateMock is HOverload {
    address public overload;

    constructor(address overload_) {
        overload = overload_;
    }

    function beforeDelegate(address, DelegationKey memory, uint256, bytes calldata, bool) external pure returns (bytes4) {}

    function afterDelegate(address, DelegationKey memory, uint256, bytes calldata, bool, Delegation memory, uint256) external pure returns (bytes4) {}

    function beforeRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata, bool) public pure returns (bytes4) {}

    function afterRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata, bool) public pure returns (bytes4) {}

    function beforeUndelegating(address, DelegationKey memory, uint256, bytes calldata, bool, uint256) external pure returns (bytes4) {}

    function afterUndelegating(address, DelegationKey memory, uint256, bytes calldata, bool, UndelegationKey memory, uint256) external pure returns (bytes4) {}

    function beforeUndelegate(address, UndelegationKey memory, int256, bytes calldata, bool, uint256) external pure returns (bytes4) {
        revert();
    }

    function afterUndelegate(address, UndelegationKey memory, int256, bytes calldata, bool) external pure returns (bytes4) {
        revert();
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == HOverload.beforeUndelegate.selector ||
            interfaceId == HOverload.afterUndelegate.selector;
    }

    function test() public {}
}

contract ConsensusNoHook {
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == HOverload.beforeDelegate.selector ||
            interfaceId == HOverload.afterDelegate.selector ||
            interfaceId == HOverload.beforeRedelegate.selector ||
            interfaceId == HOverload.afterRedelegate.selector ||
            interfaceId == HOverload.beforeUndelegating.selector ||
            interfaceId == HOverload.afterUndelegating.selector ||
            interfaceId == HOverload.beforeUndelegate.selector ||
            interfaceId == HOverload.afterUndelegate.selector;
    }

    function test() public {}
}

contract ConsensusNoERC165Interface is HOverload {
    function beforeDelegate(address, DelegationKey memory, uint256, bytes calldata, bool) external pure returns (bytes4) {}

    function afterDelegate(address, DelegationKey memory, uint256, bytes calldata, bool, Delegation memory, uint256) external pure returns (bytes4) {}

    function beforeRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata, bool) public pure returns (bytes4) {}

    function afterRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata, bool) public pure returns (bytes4) {}

    function beforeUndelegating(address, DelegationKey memory, uint256, bytes calldata, bool, uint256) external pure returns (bytes4) {}

    function afterUndelegating(address, DelegationKey memory, uint256, bytes calldata, bool, UndelegationKey memory, uint256) external pure returns (bytes4) {}

    function beforeUndelegate(address, UndelegationKey memory, int256, bytes calldata, bool, uint256) external pure returns (bytes4) {}

    function afterUndelegate(address, UndelegationKey memory, int256, bytes calldata, bool) external pure returns (bytes4) {}

    function test() public {}
}

contract ConsensusWhenERC165InterfaceReverts is HOverload {
    function beforeDelegate(address, DelegationKey memory, uint256, bytes calldata, bool) external pure returns (bytes4) {}

    function afterDelegate(address, DelegationKey memory, uint256, bytes calldata, bool, Delegation memory, uint256) external pure returns (bytes4) {}

    function beforeRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata, bool) public pure returns (bytes4) {}

    function afterRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata, bool) public pure returns (bytes4) {}

    function beforeUndelegating(address, DelegationKey memory, uint256, bytes calldata, bool, uint256) external pure returns (bytes4) {}

    function afterUndelegating(address, DelegationKey memory, uint256, bytes calldata, bool, UndelegationKey memory, uint256) external pure returns (bytes4) {}

    function beforeUndelegate(address, UndelegationKey memory, int256, bytes calldata, bool, uint256) external pure returns (bytes4) {}

    function afterUndelegate(address, UndelegationKey memory, int256, bytes calldata, bool) external pure returns (bytes4) {}

    function supportsInterface(bytes4) public pure returns (bool) {
        revert();
    }

    function test() public {}
}

contract ConsensusWrongReturnValueOnHook is HOverload {
    function beforeDelegate(address, DelegationKey memory, uint256, bytes calldata, bool) external pure returns (bytes4) {
        return HOverload.afterDelegate.selector;
    }

    function afterDelegate(address, DelegationKey memory, uint256, bytes calldata, bool, Delegation memory, uint256) external pure returns (bytes4) {}

    function beforeRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata, bool) public pure returns (bytes4) {}

    function afterRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata, bool) public pure returns (bytes4) {}

    function beforeUndelegating(address, DelegationKey memory, uint256, bytes calldata, bool, uint256) external pure returns (bytes4) {}

    function afterUndelegating(address, DelegationKey memory, uint256, bytes calldata, bool, UndelegationKey memory, uint256) external pure returns (bytes4) {}

    function beforeUndelegate(address, UndelegationKey memory, int256, bytes calldata, bool, uint256) external pure returns (bytes4) {}

    function afterUndelegate(address, UndelegationKey memory, int256, bytes calldata, bool) external pure returns (bytes4) {}

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == HOverload.beforeDelegate.selector;
    }

    function test() public {}
}

contract ConsensusInsufficientGasBudget {
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == HOverload.beforeDelegate.selector;
    }

    function test() public {}
}

contract ConsensusGasEater is HOverload {
    mapping(uint256 x => uint256 y) public slots;

    function set(uint256 x, uint256 y) public {
        slots[x] = y;
    }

    function beforeDelegate(address, DelegationKey memory, uint256, bytes calldata data, bool) external returns (bytes4) {
        uint256 runs = abi.decode(data, (uint256));

        for (uint256 i = 0; i < runs; i++) {
            set(i, i);
        }

        return HOverload.beforeDelegate.selector;
    }

    function afterDelegate(address, DelegationKey memory, uint256, bytes calldata, bool, Delegation memory, uint256) external pure returns (bytes4) {}

    function beforeRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata, bool) public pure returns (bytes4) {}

    function afterRedelegate(address, DelegationKey memory, DelegationKey memory, bytes calldata, bool) public pure returns (bytes4) {}

    function beforeUndelegating(address, DelegationKey memory, uint256, bytes calldata, bool, uint256) external pure returns (bytes4) {}

    function afterUndelegating(address, DelegationKey memory, uint256, bytes calldata, bool, UndelegationKey memory, uint256) external pure returns (bytes4) {}

    function beforeUndelegate(address, UndelegationKey memory, int256, bytes calldata, bool, uint256) external pure returns (bytes4) {}

    function afterUndelegate(address, UndelegationKey memory, int256, bytes calldata, bool) external pure returns (bytes4) {}

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == HOverload.beforeDelegate.selector;
    }

    function test() public {}
}
