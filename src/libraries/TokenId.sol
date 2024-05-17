// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

library TokenId {
    function convertToId(address token) internal pure returns (uint256 id) {
        id = uint256(uint160(token));
    }

    function convertToToken(uint256 id) internal pure returns (address token) {
        require(id <= type(uint160).max, "INVALID_ID");
        token = address(uint160(id));
    }
}
