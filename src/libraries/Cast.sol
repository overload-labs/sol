// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Cast {
    function u256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "U256_NEG");
        return uint256(value);
    }

    function i256(uint256 value) internal pure returns (int256) {
        require(value <= uint256(type(int256).max), "I256");
        return int256(value);
    }
}
