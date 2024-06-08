// SPDX-License-Identifier: MIT
pragma solidity >=0.8.26;

/// @title CastLib
library CastLib {
    /// @notice Thrown when an `int256` value is negative.
    error ValueUnderflowUint256();
    /// @notice Thrown when an `uint256` value is greater than `type(int256).max`.
    error ValueOverflowInt256();

    /// @notice Safe cast an `int256` to `uint256`.
    /// @param value The `int256` value.
    function u256(int256 value) internal pure returns (uint256) {
        require(value >= 0, ValueUnderflowUint256());
        return uint256(value);
    }

    /// @notice Safe cast an `uint256` to `int256`.
    /// @param value The `uint256` value.
    function i256(uint256 value) internal pure returns (int256) {
        require(value <= uint256(type(int256).max), ValueOverflowInt256());
        return int256(value);
    }
}
