// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Test, console, console2, stdError} from "forge-std/Test.sol";

import {TokenIdLib} from "../src/libraries/TokenIdLib.sol";

contract TokenIdContract {
    function convertToId(address token) public pure returns (uint256) {
        return TokenIdLib.convertToId(token);
    }

    function convertToToken(uint256 id) public pure returns (address token) {
        return TokenIdLib.convertToToken(id);
    }

    function test() public {}
}

contract TokenIdTest is Test {
    TokenIdContract public tokenId;

    function setUp() public {
        tokenId = new TokenIdContract();
    }

    function test_convertToId() public view {
        assertEq(tokenId.convertToId(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF), (2 ** 160) - 1);
        assertEq(tokenId.convertToId(address(0)), 0);
        assertEq(tokenId.convertToId(address(0xF)), 15);
    }

    function test_convertToToken() public view {
        assertEq(tokenId.convertToToken((2 ** 160) - 1), 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
        assertEq(tokenId.convertToToken(0), address(0));
        assertEq(tokenId.convertToToken(15), address(0xF));
    }

    function test_fail_convertToToken() public {
        // Should not revert
        tokenId.convertToToken((2 ** 160) - 1);

        // Should revert
        vm.expectRevert(abi.encodeWithSelector(TokenIdLib.InvalidId.selector, 2 ** 160));
        tokenId.convertToToken(2 ** 160);
        vm.expectRevert(abi.encodeWithSelector(TokenIdLib.InvalidId.selector, type(uint256).max));
        tokenId.convertToToken(type(uint256).max);
    }
}
