// SPDX-License-Identifier: MIT
pragma solidity >=0.8.26;

/// @title TokenIdLib
library TokenIdLib {
    /// @notice Thrown when an id is invalid as a token address.
    /// @dev The id is greater than `type(uint160).max`.
    /// @param id The invalid token id.
    error InvalidId(uint256 id);

    /// @notice Convert a token address to an token id.
    /// @param token The token address.
    function convertToId(address token) internal pure returns (uint256 id) {
        id = uint256(uint160(token));
    }

    /// @notice Convert a token id to a token address.
    /// @param id The token id.
    function convertToToken(uint256 id) internal pure returns (address token) {
        require(id <= type(uint160).max, InvalidId(id));
        token = address(uint160(id));
    }
}
