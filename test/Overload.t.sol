// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Test, console, console2, stdError} from "forge-std/Test.sol";

import {DelegationKey} from "../src/libraries/types/Delegation.sol";
import {TokenIdLib} from "../src/libraries/TokenIdLib.sol";
import {Overload} from "../src/Overload.sol";

import {ERC20Fee} from "./mocks/ERC20Fee.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract OverloadTest is Test {
    using TokenIdLib for uint256;
    using TokenIdLib for address;

    event Deposit(address indexed caller, address indexed owner, address indexed token, uint256 amount);
    event Withdraw(address indexed caller, address owner, address indexed token, uint256 amount, address recipient);

    ERC20Mock public token;
    Overload public overload;

    function setUp() public {
        token = new ERC20Mock("Test", "TEST", 18);
        overload = new Overload();
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function deposit(address user) public {
        token.mint(user, 100);

        vm.prank(user);
        token.approve(address(overload), 100);
        vm.prank(user);
        overload.deposit(user, address(token), 100);
    }

    function delegate(address user, address consensus, address validator, uint256 amount, bool strict) public {
        DelegationKey memory key = DelegationKey({
            owner: user,
            token: address(token),
            consensus: consensus,
            validator: validator
        });

        vm.prank(user);
        overload.delegate(key, amount, "", strict);
    }

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                                WITHDRAW
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                                DELEGATE
    //////////////////////////////////////////////////////////////*/

    function test_delegate() public {
        deposit(address(0xBEEF));

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xCCCC),
            validator: address(0xFFFF)
        });

        vm.prank(address(0xBEEF));
        vm.expectEmit();
        emit Overload.Delegate(key, 50, "", false);
        assertTrue(overload.delegate(key, 50, "", false));
        assertEq(overload.getDelegationsLength(address(0xBEEF), address(token)), 1);
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).consensus, address(0xCCCC));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).validator, address(0xFFFF));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).amount, 50);

        assertEq(overload.bonded(address(0xBEEF), address(token)), 50);
        assertTrue(overload.delegated(address(0xBEEF), address(token), address(0xCCCC)));
    }

    function test_delegate_overflow() public {
        deposit(address(0xBEEF));

        vm.expectRevert(Overload.Overflow.selector);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 101, true);
    }

    function test_delegate_overflow_additional() public {
        deposit(address(0xBEEF));

        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 50, true);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 50, true);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 100);

        vm.expectRevert(Overload.Overflow.selector);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 1, true);
    }

    function test_delegate_max_delegations() public {
        deposit(address(0xBEEF));
    }

    function test_delegate_zero() public {
        deposit(address(0xBEEF));

        vm.expectRevert();
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 0, true);
    }
}
