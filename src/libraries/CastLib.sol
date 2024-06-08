// SPDX-License-Identifier: MIT
pragma solidity >=0.8.26;

library CastLib {
    error ValueUnderflowUint256();
    error ValueOverflowInt256();

    function u256(int256 value) internal pure returns (uint256) {
        require(value >= 0, ValueUnderflowUint256());
        return uint256(value);
    }

    function i256(uint256 value) internal pure returns (int256) {
        require(value <= uint256(type(int256).max), ValueOverflowInt256());
        return int256(value);
    }
}
