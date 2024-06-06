// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Test, console, console2, stdError} from "forge-std/Test.sol";

import {TokenIdLib} from "../src/libraries/TokenIdLib.sol";
import {Overload} from "../src/Overload.sol";

import {ERC20Fee} from "./mocks/ERC20Fee.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract OverloadTest is Test {
    using TokenIdLib for uint256;
    using TokenIdLib for address;

    event Deposit(address indexed caller, address indexed owner, address indexed token, uint256 amount);
    event Withdraw(address indexed caller, address owner, address indexed token, uint256 amount, address recipient);

    Overload public overload;
    ERC20Mock public token;

    function setUp() public {
        overload = new Overload();
        token = new ERC20Mock("Test", "TEST", 18);
    }

    function test_deposit() public {
        token.mint(address(0xBEEF), 100);

        vm.prank(address(0xBEEF));
        token.approve(address(overload), 100);

        vm.prank(address(0xBEEF));
        vm.expectEmit(true, true, true, true);
        emit Deposit(address(0xBEEF), address(0xBEEF), address(token), 100);
        overload.deposit(address(0xBEEF), address(token), 100);

        assertEq(overload.balanceOf(address(0xBEEF), address(token).convertToId()), 100);
    }

    function test_withdraw() public {
        token.mint(address(0xBEEF), 100);

        vm.prank(address(0xBEEF));
        token.approve(address(overload), 100);
        vm.prank(address(0xBEEF));
        overload.deposit(address(0xBEEF), address(token), 100);

        vm.prank(address(0xBEEF));
        vm.expectEmit(true, true, true, true);
        emit Withdraw(address(0xBEEF), address(0xBEEF), address(token), 100, address(0xBEEF));
        overload.withdraw(address(0xBEEF), address(token), 100, address(0xBEEF));

        assertEq(overload.balanceOf(address(0xBEEF), address(token).convertToId()), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 100);
    }

    function test_deposit_fee() public {
        vm.prank(address(0xBEEF));
        ERC20Fee tokenFee = new ERC20Fee(1e18, 1_000);

        vm.prank(address(0xBEEF));
        tokenFee.approve(address(overload), 10_000);

        vm.prank(address(0xBEEF));
        vm.expectEmit(true, true, true, true);
        emit Deposit(address(0xBEEF), address(0xBEEF), address(tokenFee), 9_000);
        overload.deposit(address(0xBEEF), address(tokenFee), 10_000);

        assertEq(overload.balanceOf(address(0xBEEF), address(tokenFee).convertToId()), 9_000);
    }

    function test_withdraw_fee() public {
        vm.prank(address(0xBEEF));
        ERC20Fee tokenFee = new ERC20Fee(1e18, 1_000);

        vm.prank(address(0xBEEF));
        tokenFee.approve(address(overload), 10_000);
        vm.prank(address(0xBEEF));
        overload.deposit(address(0xBEEF), address(tokenFee), 10_000);

        vm.prank(address(0xBEEF));
        vm.expectEmit(true, true, true, true);
        emit Withdraw(address(0xBEEF), address(0xBEEF), address(tokenFee), 9_000, address(0xBEEF));
        overload.withdraw(address(0xBEEF), address(tokenFee), 9_000, address(0xBEEF));

        assertEq(overload.balanceOf(address(0xBEEF), address(tokenFee).convertToId()), 0);
        assertEq(tokenFee.balanceOf(address(0xBEEF)), 1e18 - 2_000);
    }
}
