// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Test, console, console2, stdError} from "forge-std/Test.sol";

import {EOverload} from "../src/interfaces/EOverload.sol";
import {DelegationNotFound, DelegationKey} from "../src/libraries/types/Delegation.sol";
import {UndelegationNotFound, UndelegationKey} from "../src/libraries/types/Undelegation.sol";
import {TokenIdLib} from "../src/libraries/TokenIdLib.sol";
import {Overload} from "../src/Overload.sol";

import {ERC20Fee} from "./mocks/ERC20Fee.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract OverloadFuzzTest is Test {
    using TokenIdLib for uint256;
    using TokenIdLib for address;

    Overload public overload;

    ERC20Mock public token;
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    ERC20Fee public tokenFee;

    function setUp() public {
        overload = new Overload();
        token = new ERC20Mock("Test", "TEST", 18);
    }

    /*//////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function test_fuzz_deposit(address owner, uint256 amount) public {
        if (owner == address(overload)) {
            return;
        }

        token.mint(owner, amount);

        vm.prank(owner);
        token.approve(address(overload), amount);

        if (amount == 0) {
            vm.prank(owner);
            vm.expectRevert(EOverload.Zero.selector);
            overload.deposit(owner, address(token), amount);
        } else {
            vm.prank(owner);
            vm.expectEmit(true, true, true, true);
            emit EOverload.Deposit(owner, owner, address(token), amount);
            assertTrue(overload.deposit(owner, address(token), amount));
        }

        assertEq(overload.balanceOf(owner, address(token).convertToId()), amount);
    }

    function test_fuzz_withdraw(address owner, uint256 depositAmount, uint256 withdrawAmount, address recipient) public {
        if (owner == address(overload)) {
            return;
        }

        token.mint(owner, depositAmount);

        vm.prank(owner);
        token.approve(address(overload), depositAmount);
        if (depositAmount == 0) {
            vm.prank(owner);
            vm.expectRevert(EOverload.Zero.selector);
            overload.deposit(owner, address(token), depositAmount);
        } else {
            vm.prank(owner);
            assertTrue(overload.deposit(owner, address(token), depositAmount));
        }

        if (withdrawAmount == 0) {
            vm.prank(owner);
            vm.expectRevert(EOverload.Zero.selector);
            overload.withdraw(owner, address(token), withdrawAmount, owner);
        } else if (withdrawAmount > depositAmount) {
            vm.prank(owner);
            vm.expectRevert(stdError.arithmeticError);
            overload.withdraw(owner, address(token), withdrawAmount, owner);
        } else {
            vm.prank(owner);
            vm.expectEmit(true, true, true, true);
            emit EOverload.Withdraw(owner, owner, address(token), withdrawAmount, recipient);
            assertTrue(overload.withdraw(owner, address(token), withdrawAmount, recipient));
            
            assertEq(overload.balanceOf(owner, address(token).convertToId()), depositAmount - withdrawAmount);

            if (recipient != address(overload)) {
                assertEq(token.balanceOf(recipient), withdrawAmount);
            }
        }
    }

    function test_fuzz_delegate(address owner, address consensus, address validator, uint256 amount, bytes memory data, bool strict) public {
        if (owner == address(overload)) {
            return;
        }

        // Mint
        token.mint(owner, amount);

        // Delegate
        DelegationKey memory key = DelegationKey({
            owner: owner,
            token: address(token),
            consensus: consensus,
            validator: validator
        });

        if (amount == 0) {
            vm.prank(owner);
            vm.expectRevert(EOverload.Zero.selector);
            overload.delegate(key, amount, data, strict);
        } else {
            // Deposit
            vm.prank(owner);
            token.approve(address(overload), amount);
            vm.prank(owner);
            overload.deposit(owner, address(token), amount);

            // Delegate
            vm.prank(owner);
            vm.expectEmit(true, true, true, true);
            emit EOverload.Delegate(key, amount, data, strict);
            assertTrue(overload.delegate(key, amount, data, strict));

            assertEq(overload.getDelegationsLength(owner, address(token)), 1);
            assertEq(overload.getDelegation(owner, address(token), 0).consensus, consensus);
            assertEq(overload.getDelegation(owner, address(token), 0).validator, validator);
            assertEq(overload.getDelegation(owner, address(token), 0).amount, amount);
            assertEq(overload.balanceOf(owner, address(token).convertToId()), 0);
            assertEq(overload.bonded(owner, address(token)), amount);
            assertTrue(overload.delegated(owner, address(token), consensus));
        }
    }
}
