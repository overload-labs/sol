// SPDX-License-Identifier: MIT
pragma solidity >=0.8.26;

library TokenIdLib {
    error InvalidId(uint256 id);

    function convertToId(address token) internal pure returns (uint256 id) {
        id = uint256(uint160(token));
    }

    function convertToToken(uint256 id) internal pure returns (address token) {
        require(id <= type(uint160).max, InvalidId(id));
        token = address(uint160(id));
    }
}
