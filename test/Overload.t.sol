// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Test, console, console2, stdError} from "forge-std/Test.sol";

import {DelegationNotFound, DelegationKey} from "../src/libraries/types/Delegation.sol";
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

    function setUp() public {
        overload = new Overload();

        token = new ERC20Mock("Test", "TEST", 18);
        tokenA = new ERC20Mock("Token A", "A", 18);
        tokenB = new ERC20Mock("Token B", "B", 18);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function deposit(address user, uint256 amount) public {
        token.mint(user, amount);

        vm.prank(user);
        token.approve(address(overload), amount);
        vm.prank(user);
        overload.deposit(user, address(token), amount);
    }

    function deposit(ERC20Mock token_, address user, uint256 amount) public {
        token_.mint(user, amount);

        vm.prank(user);
        token_.approve(address(overload), amount);
        vm.prank(user);
        overload.deposit(user, address(token_), amount);
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

    function delegate(ERC20Mock token_, address user, address consensus, address validator, uint256 amount, bool strict) public {
        DelegationKey memory key = DelegationKey({
            owner: user,
            token: address(token_),
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
        emit Overload.Deposit(address(0xBEEF), address(0xBEEF), address(token), 100);
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
        emit Overload.Deposit(address(0xBEEF), address(0xBEEF), address(tokenFee), 9_000);
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
        emit Overload.Withdraw(address(0xBEEF), address(0xBEEF), address(token), 100, address(0xBEEF));
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
        emit Overload.Withdraw(address(0xBEEF), address(0xBEEF), address(tokenFee), 9_000, address(0xBEEF));
        overload.withdraw(address(0xBEEF), address(tokenFee), 9_000, address(0xBEEF));

        assertEq(overload.balanceOf(address(0xBEEF), address(tokenFee).convertToId()), 0);
        assertEq(tokenFee.balanceOf(address(0xBEEF)), 1e18 - 2_000);
    }

    /*//////////////////////////////////////////////////////////////
                                DELEGATE
    //////////////////////////////////////////////////////////////*/

    function test_delegate() public {
        deposit(address(0xBEEF), 100);

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xCCCC),
            validator: address(0xFFFF)
        });

        vm.prank(address(0xBEEF));
        vm.expectEmit(true, true, true, true);
        emit Overload.Delegate(key, 50, "", false);
        assertTrue(overload.delegate(key, 50, "", false));
        assertEq(overload.getDelegationsLength(address(0xBEEF), address(token)), 1);
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).consensus, address(0xCCCC));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).validator, address(0xFFFF));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).amount, 50);

        assertEq(overload.bonded(address(0xBEEF), address(token)), 50);
        assertTrue(overload.delegated(address(0xBEEF), address(token), address(0xCCCC)));
    }

    // Should delegate to same consensus and validator multiple times
    function test_delegate_multiple() public {
        deposit(address(0xBEEF), 100);

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xCCCC),
            validator: address(0xFFFF)
        });

        // first 50
        vm.prank(address(0xBEEF));
        vm.expectEmit(true, true, true, true);
        emit Overload.Delegate(key, 50, "", false);
        assertTrue(overload.delegate(key, 50, "", false));
        assertEq(overload.getDelegationsLength(address(0xBEEF), address(token)), 1);
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).consensus, address(0xCCCC));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).validator, address(0xFFFF));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).amount, 50);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 50);
        assertTrue(overload.delegated(address(0xBEEF), address(token), address(0xCCCC)));

        // second 50, total 100
        vm.prank(address(0xBEEF));
        vm.expectEmit(true, true, true, true);
        emit Overload.Delegate(key, 50, "", false);
        assertTrue(overload.delegate(key, 50, "", false));
        assertEq(overload.getDelegationsLength(address(0xBEEF), address(token)), 1);
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).consensus, address(0xCCCC));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).validator, address(0xFFFF));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).amount, 100);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 100);
        assertTrue(overload.delegated(address(0xBEEF), address(token), address(0xCCCC)));
    }

    function test_delegate_multipleConsensus() public {
        deposit(address(0xBEEF), 100);

        // Delegates to 6 different consensus contracts, some validators for the same.
        // 100 * 6 = 600
        delegate(address(0xBEEF), address(0xA), address(0x1), 100, true);
        delegate(address(0xBEEF), address(0xB), address(0x2), 100, true);
        delegate(address(0xBEEF), address(0xC), address(0x3), 100, true);
        delegate(address(0xBEEF), address(0xD), address(0x4), 100, true);
        delegate(address(0xBEEF), address(0xE), address(0x1), 100, true);
        delegate(address(0xBEEF), address(0xF), address(0x1), 100, true);

        assertEq(overload.getDelegationsLength(address(0xBEEF), address(token)), 6);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 100);
    }

    function test_delegate_multipleTokensMultipleConsensus() public {
        deposit(tokenA, address(0xBEEF), 100);
        deposit(tokenB, address(0xBEEF), 100);

        delegate(tokenA, address(0xBEEF), address(0xA), address(0x1), 100, true);
        delegate(tokenA, address(0xBEEF), address(0xB), address(0x2), 100, true);
        delegate(tokenA, address(0xBEEF), address(0xC), address(0x3), 100, true);
        delegate(tokenA, address(0xBEEF), address(0xD), address(0x4), 100, true);
        delegate(tokenA, address(0xBEEF), address(0xE), address(0x1), 100, true);
        delegate(tokenA, address(0xBEEF), address(0xF), address(0x1), 100, true);

        delegate(tokenB, address(0xBEEF), address(0xA), address(0x1), 100, true);
        delegate(tokenB, address(0xBEEF), address(0xB), address(0x2), 100, true);
        delegate(tokenB, address(0xBEEF), address(0xC), address(0x3), 100, true);
        delegate(tokenB, address(0xBEEF), address(0xD), address(0x4), 100, true);
        delegate(tokenB, address(0xBEEF), address(0xE), address(0x1), 100, true);
        delegate(tokenB, address(0xBEEF), address(0xF), address(0x1), 50, true);

        // Should revert when trying to delegate to another validator when existing (consensus, validator) exists
        vm.expectRevert(DelegationNotFound.selector);
        delegate(tokenB, address(0xBEEF), address(0xF), address(0x2), 100, true);

        // Should delegate another time
        delegate(tokenB, address(0xBEEF), address(0xF), address(0x1), 50, true);

        // Should overflow
        vm.expectRevert(Overload.Overflow.selector);
        delegate(tokenB, address(0xBEEF), address(0xF), address(0x1), 1, true);

        assertEq(overload.getDelegationsLength(address(0xBEEF), address(tokenA)), 6);
        assertEq(overload.getDelegationsLength(address(0xBEEF), address(tokenB)), 6);
        assertEq(overload.bonded(address(0xBEEF), address(tokenA)), 100);
        assertEq(overload.bonded(address(0xBEEF), address(tokenB)), 100);
    }

    function test_delegate_approval() public {
        deposit(address(0xBEEF), 100);

        // Approve
        vm.prank(address(0xBEEF));
        overload.approve(address(0xABCD), address(token).convertToId(), type(uint256).max);

        // Delegate through another user
        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xCCCC),
            validator: address(0xFFFF)
        });
        vm.prank(address(0xABCD));
        overload.delegate(key, 100, "", true);
    }

    function test_delegate_operator() public {
        deposit(address(0xBEEF), 100);

        // Approve
        vm.prank(address(0xBEEF));
        overload.setOperator(address(0xABCD), true);

        // Delegate through another user
        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xCCCC),
            validator: address(0xFFFF)
        });
        vm.prank(address(0xABCD));
        overload.delegate(key, 100, "", true);
    }

    function test_delegate_withData() public {
        deposit(address(0xBEEF), 100);

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xCCCC),
            validator: address(0xFFFF)
        });
        vm.prank(address(0xBEEF));
        vm.expectEmit(true, true, true, true);
        emit Overload.Delegate(key, 100, abi.encodePacked(uint256(42)), true);
        overload.delegate(key, 100, abi.encodePacked(uint256(42)), true);
    }

    // Should fail to delegate to two different validators for a single consensus address
    // The second call reverts as the lookup of the delegation fails with strict, not because it already exists
    function test_fail_delegate_differentDelegationExists() public {
        deposit(address(0xBEEF), 100);

        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 50, true);
        vm.expectRevert(DelegationNotFound.selector);
        delegate(address(0xBEEF), address(0xCCCC), address(0xEEEE), 50, false);
    }

    function test_fail_delegate_overflow() public {
        deposit(address(0xBEEF), 100);

        vm.expectRevert(Overload.Overflow.selector);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 101, true);
    }

    function test_fail_delegate_overflowAdditional() public {
        deposit(address(0xBEEF), 100);

        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 50, true);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 50, true);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 100);

        vm.expectRevert(Overload.Overflow.selector);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 1, true);
    }

    function test_fail_delegate_zero() public {
        deposit(address(0xBEEF), 100);

        vm.expectRevert();
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 0, true);
    }

    function test_fail_delegate_noApprovalNotOperator() public {
        deposit(address(0xBEEF), 100);

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xCCCC),
            validator: address(0xFFFF)
        });
        vm.prank(address(0xABCD));
        vm.expectRevert(stdError.arithmeticError);
        overload.delegate(key, 100, "", true);
    }

    function test_fail_delegate_maxDelegations() public {
        deposit(address(0xBEEF), 1000);

        for (uint256 i = 1; i < 256 + 1; i++) {
            delegate(address(0xBEEF), address(uint160(i)), address(uint160(i)), 1, true);
        }

        vm.expectRevert(Overload.MaxDelegationsReached.selector);
        delegate(address(0xBEEF), address(uint160(123)), address(uint160(123)), 1, true);
    }
}
