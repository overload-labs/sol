// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Test, console, console2, stdError} from "forge-std/Test.sol";

import {DelegationNotFound, DelegationKey} from "../src/libraries/types/Delegation.sol";
import {UndelegationNotFound, UndelegationKey} from "../src/libraries/types/Undelegation.sol";
import {TokenIdLib} from "../src/libraries/TokenIdLib.sol";
import {Overload} from "../src/Overload.sol";

import {ERC20Fee} from "./mocks/ERC20Fee.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract OverloadTest is Test {
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

    function test_deposit(address owner, uint256 amount) public {
        if (owner == address(overload)) {
            return;
        }

        token.mint(owner, amount);

        vm.prank(owner);
        token.approve(address(overload), amount);

        if (amount == 0) {
            vm.prank(owner);
            vm.expectRevert(Overload.Zero.selector);
            overload.deposit(owner, address(token), amount);
        } else {
            vm.prank(owner);
            vm.expectEmit(true, true, true, true);
            emit Overload.Deposit(owner, owner, address(token), amount);
            assertTrue(overload.deposit(owner, address(token), amount));
        }

        assertEq(overload.balanceOf(owner, address(token).convertToId()), amount);
    }

    function test_withdraw(address owner, uint256 depositAmount, uint256 withdrawAmount, address recipient) public {
        if (owner == address(overload)) {
            return;
        }

        token.mint(owner, depositAmount);

        vm.prank(owner);
        token.approve(address(overload), depositAmount);
        if (depositAmount == 0) {
            vm.prank(owner);
            vm.expectRevert(Overload.Zero.selector);
            overload.deposit(owner, address(token), depositAmount);
        } else {
            vm.prank(owner);
            assertTrue(overload.deposit(owner, address(token), depositAmount));
        }

        if (withdrawAmount == 0) {
            vm.prank(owner);
            vm.expectRevert(Overload.Zero.selector);
            overload.withdraw(owner, address(token), withdrawAmount, owner);
        } else if (withdrawAmount > depositAmount) {
            vm.prank(owner);
            vm.expectRevert(stdError.arithmeticError);
            overload.withdraw(owner, address(token), withdrawAmount, owner);
        } else {
            vm.prank(owner);
            vm.expectEmit(true, true, true, true);
            emit Overload.Withdraw(owner, owner, address(token), withdrawAmount, recipient);
            assertTrue(overload.withdraw(owner, address(token), withdrawAmount, recipient));
            
            assertEq(overload.balanceOf(owner, address(token).convertToId()), depositAmount - withdrawAmount);

            if (recipient != address(overload)) {
                assertEq(token.balanceOf(recipient), withdrawAmount);
            }
        }
    }
}
