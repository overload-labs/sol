// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

/// @title Lock
/// @dev Prevents reentrancy.
abstract contract Lock {
    error Locked();

    bool public __locked = false;

    modifier lock() {
        require(!__locked, Locked());
        __locked = true;
        _;
        __locked = false;
    }
}
