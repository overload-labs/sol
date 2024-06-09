// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Test, console, console2, stdError} from "forge-std/Test.sol";

import {EOverload} from "../src/interfaces/EOverload.sol";
import {Delegation, DelegationKey, DelegationLib} from "../src/libraries/types/Delegation.sol";
import {Undelegation, UndelegationKey, UndelegationLib} from "../src/libraries/types/Undelegation.sol";
import {TokenIdLib} from "../src/libraries/TokenIdLib.sol";
import {Overload} from "../src/Overload.sol";

import {ERC20Fee} from "./mocks/ERC20Fee.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract OverloadTest is EOverload, Test {
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
        tokenA = new ERC20Mock("Token A", "A", 18);
        tokenB = new ERC20Mock("Token B", "B", 18);

        vm.prank(address(0xBEEF));
        tokenFee = new ERC20Fee(1e18, 1_000);
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

    function redelegate(address user, address consensus, address fromValidator, address toValidator) public returns (bool) {
        DelegationKey memory fromKey = DelegationKey({
            owner: user,
            token: address(token),
            consensus: consensus,
            validator: fromValidator
        });
        DelegationKey memory toKey = DelegationKey({
            owner: user,
            token: address(token),
            consensus: consensus,
            validator: toValidator
        });

        vm.prank(user);
        return overload.redelegate(fromKey, toKey, "", true);
    }

    function undelegating(address user, address consensus, address validator, uint256 amount, bool strict) public returns (bool success, UndelegationKey memory, int256) {
        DelegationKey memory key = DelegationKey({
            owner: user,
            token: address(token),
            consensus: consensus,
            validator: validator
        });

        vm.prank(user);
        return overload.undelegating(key, amount, "", strict);
    }

    function undelegating(ERC20Mock token_, address user, address consensus, address validator, uint256 amount, bool strict) public returns (bool success, UndelegationKey memory, int256) {
        DelegationKey memory key = DelegationKey({
            owner: user,
            token: address(token_),
            consensus: consensus,
            validator: validator
        });

        vm.prank(user);
        return overload.undelegating(key, amount, "", strict);
    }

    function undelegate(address user, UndelegationKey memory ukey, int256 position, bytes memory data, bool strict) public {
        vm.prank(user);
        overload.undelegate(ukey, position, data, strict);
    }

    function setDelay(address consensus, uint256 delay) public {
        vm.prank(consensus);
        overload.setDelay(consensus, delay);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /**
     * Delegation
     */

    function test_getDelegations() public {
        deposit(address(0xBEEF), 1e18);

        for (uint256 i = 1; i < 256 + 1; i++) {
            delegate(address(0xBEEF), address(uint160(i)), address(uint160(i)), i, true);
        }

        Delegation[] memory delegations = overload.getDelegations(address(0xBEEF), address(token));
        assertEq(overload.getDelegationsLength(address(0xBEEF), address(token)), 256);

        for (uint256 i = 0; i < delegations.length; i++) {
            assertEq(overload.getDelegation(address(0xBEEF), address(token), i).consensus, address(uint160(i + 1)));
            assertEq(overload.getDelegation(address(0xBEEF), address(token), i).validator, address(uint160(i + 1)));
            assertEq(overload.getDelegation(address(0xBEEF), address(token), i).amount, i + 1);
        }
    }

    function test_getDelegation_empty() public view {
        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xCCCC),
            validator: address(0xFFFF)
        });

        Delegation memory delegation = overload.getDelegation(key);
        assertEq(delegation.consensus, address(0));
        assertEq(delegation.validator, address(0));
        assertEq(delegation.amount, 0);
    }

    /**
     * Undelegation
     */

    function test_getUndelegations() public {
        setDelay(address(0xCCCC), 500);
        deposit(address(0xBEEF), 1e18);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 1e18, true);

        for (uint256 i = 0; i < 32; i++) {
            undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), i + 1, true);
        }

        Undelegation[] memory undelegations = overload.getUndelegations(address(0xBEEF), address(token));
        assertEq(overload.getUndelegationLength(address(0xBEEF), address(token)), 32);

        for (uint256 i = 0; i < undelegations.length; i++) {
            assertEq(overload.getUndelegation(address(0xBEEF), address(token), i).consensus, address(0xCCCC));
            assertEq(overload.getUndelegation(address(0xBEEF), address(token), i).validator, address(0xFFFF));
            assertEq(overload.getUndelegation(address(0xBEEF), address(token), i).amount, i + 1);
            assertEq(overload.getUndelegation(address(0xBEEF), address(token), i).maturity, 501);
        }
    }

    function test_getUndelegation_zero() public view {
        assertEq(overload.getUndelegation(address(0xBEEF), address(token), 100).consensus, address(0));
        assertEq(overload.getUndelegation(address(0xBEEF), address(token), 100).validator, address(0));
        assertEq(overload.getUndelegation(address(0xBEEF), address(token), 100).amount, 0);
        assertEq(overload.getUndelegation(address(0xBEEF), address(token), 100).maturity, 0);

        UndelegationKey memory ukey = UndelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xCCCC),
            validator: address(0xFFFF),
            amount: 100,
            maturity: 1
        });
        assertEq(overload.getUndelegation(ukey).consensus, address(0));
        assertEq(overload.getUndelegation(ukey).validator, address(0));
        assertEq(overload.getUndelegation(ukey).amount, 0);
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

    function test_withdraw_approval() public {
        deposit(address(0xBEEF), 100);

        // Approve max
        vm.prank(address(0xBEEF));
        overload.approve(address(0xABCD), address(token).convertToId(), type(uint256).max);
        // Withdraw with max approval
        vm.prank(address(0xABCD));
        overload.withdraw(address(0xBEEF), address(token), 50, address(0xABCD));
        assertEq(overload.allowance(address(0xBEEF), address(0xABCD), address(token).convertToId()), type(uint256).max);
        assertEq(token.balanceOf(address(0xABCD)), 50);

        // Approve non-max
        vm.prank(address(0xBEEF));
        overload.approve(address(0xABCD), address(token).convertToId(), 1e18);
        // Withdraw with non-max approval
        vm.prank(address(0xABCD));
        overload.withdraw(address(0xBEEF), address(token), 50, address(0xABCD));
        assertEq(overload.allowance(address(0xBEEF), address(0xABCD), address(token).convertToId()), 1e18 - 50);
        assertEq(token.balanceOf(address(0xABCD)), 100);
    }

    function test_withdraw_operator() public {
        deposit(address(0xBEEF), 100);

        // Set operator
        vm.prank(address(0xBEEF));
        overload.setOperator(address(0xABCD), true);
        // Withdraw as operator
        vm.prank(address(0xABCD));
        overload.withdraw(address(0xBEEF), address(token), 100, address(0xABCD));
        assertEq(token.balanceOf(address(0xABCD)), 100);
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
        emit Delegate(key, 50, "", false, 0);
        bool success = overload.delegate(key, 50, "", false);
        assertEq(success, true);
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
        emit Delegate(key, 50, "", false, 0);
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
        emit Delegate(key, 50, "", false, 0);
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
        vm.expectRevert(DelegationLib.DelegationNotFound.selector);
        delegate(tokenB, address(0xBEEF), address(0xF), address(0x2), 100, true);

        // Should delegate another time
        delegate(tokenB, address(0xBEEF), address(0xF), address(0x1), 50, true);

        // Should overflow
        vm.expectRevert(EOverload.Overflow.selector);
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
        emit Delegate(key, 100, abi.encodePacked(uint256(42)), true, 0);
        overload.delegate(key, 100, abi.encodePacked(uint256(42)), true);
    }

    // Should fail to delegate to two different validators for a single consensus address
    // The second call reverts as the lookup of the delegation fails with strict, not because it already exists
    function test_fail_delegate_differentDelegationExists() public {
        deposit(address(0xBEEF), 100);

        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 50, true);
        vm.expectRevert(DelegationLib.DelegationNotFound.selector);
        delegate(address(0xBEEF), address(0xCCCC), address(0xEEEE), 50, false);
    }

    function test_fail_delegate_overflow() public {
        deposit(address(0xBEEF), 100);

        vm.expectRevert(EOverload.Overflow.selector);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 101, true);
    }

    function test_fail_delegate_overflowAdditional() public {
        deposit(address(0xBEEF), 100);

        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 50, true);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 50, true);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 100);

        vm.expectRevert(EOverload.Overflow.selector);
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

        vm.expectRevert(EOverload.MaxDelegationsReached.selector);
        delegate(address(0xBEEF), address(uint160(123)), address(uint160(123)), 1, true);
    }

    /*//////////////////////////////////////////////////////////////
                               REDELEGATE
    //////////////////////////////////////////////////////////////*/

    function test_redelegate() public {
        deposit(address(0xBEEF), 1000);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 50, true);

        assertTrue(redelegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), address(0xEEEE)));
        assertEq(overload.getDelegationsLength(address(0xBEEF), address(token)), 1);
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).consensus, address(0xCCCC));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).validator, address(0xEEEE));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).amount, 50);
    }

    function test_fail_redelegate_sameValidator() public {
        deposit(address(0xBEEF), 1000);

        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 50, true);
        vm.expectRevert(EOverload.Zero.selector);
        redelegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), address(0xFFFF));
    }

    function test_fail_redelegate_mismatch() public {
        deposit(address(0xBEEF), 1000);

        DelegationKey memory fromKey = DelegationKey({
            owner: address(0),
            token: address(0),
            consensus: address(0),
            validator: address(0)
        });
        DelegationKey memory toKey = DelegationKey({
            owner: address(0),
            token: address(0),
            consensus: address(0),
            validator: address(0)
        });

        // Case `owner` mismatch
        fromKey.owner = address(0xBEEF);
        fromKey.token = address(token);
        fromKey.consensus = address(0xCCCC);
        fromKey.validator = address(0xFFFF);
        toKey.owner = address(0xABCD);
        toKey.token = address(token);
        toKey.consensus = address(0xCCCC);
        toKey.validator = address(0xFFFF);

        vm.prank(address(0xBEEF));
        vm.expectRevert(abi.encodeWithSelector(EOverload.MismatchAddress.selector, address(0xBEEF), address(0xABCD)));
        overload.redelegate(fromKey, toKey, "", true);
        vm.prank(address(0xBEEF));
        vm.expectRevert(abi.encodeWithSelector(EOverload.MismatchAddress.selector, address(0xBEEF), address(0xABCD)));
        overload.redelegate(fromKey, toKey, "", false);

        // Case `token` mismatch
        fromKey.owner = address(0xBEEF);
        fromKey.token = address(token);
        fromKey.consensus = address(0xCCCC);
        fromKey.validator = address(0xFFFF);
        toKey.owner = address(0xBEEF);
        toKey.token = address(tokenA);
        toKey.consensus = address(0xCCCC);
        toKey.validator = address(0xFFFF);

        vm.prank(address(0xBEEF));
        vm.expectRevert(abi.encodeWithSelector(EOverload.MismatchAddress.selector, address(token), address(tokenA)));
        overload.redelegate(fromKey, toKey, "", true);
        vm.prank(address(0xBEEF));
        vm.expectRevert(abi.encodeWithSelector(EOverload.MismatchAddress.selector, address(token), address(tokenA)));
        overload.redelegate(fromKey, toKey, "", false);

        // Case `consensus` mismatch
        fromKey.owner = address(0xBEEF);
        fromKey.token = address(token);
        fromKey.consensus = address(0xCCCC);
        fromKey.validator = address(0xFFFF);
        toKey.owner = address(0xBEEF);
        toKey.token = address(token);
        toKey.consensus = address(0xCCCA);
        toKey.validator = address(0xFFFF);

        vm.prank(address(0xBEEF));
        vm.expectRevert(abi.encodeWithSelector(EOverload.MismatchAddress.selector, address(0xCCCC), address(0xCCCA)));
        overload.redelegate(fromKey, toKey, "", true);
        vm.prank(address(0xBEEF));
        vm.expectRevert(abi.encodeWithSelector(EOverload.MismatchAddress.selector, address(0xCCCC), address(0xCCCA)));
        overload.redelegate(fromKey, toKey, "", false);
    }

    function test_fail_redelegate_delegationNotFound() public {
        deposit(address(0xBEEF), 1000);

        vm.expectRevert(DelegationLib.DelegationNotFound.selector);
        redelegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), address(0xEEEE));
    }

    /*//////////////////////////////////////////////////////////////
                              UNDELEGATING
    //////////////////////////////////////////////////////////////*/

    function test_undelegating_noDelay() public {
        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 50, true);

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xCCCC),
            validator: address(0xFFFF)
        });
        vm.prank(address(0xBEEF));
        vm.expectEmit(true, true, true, true);
        UndelegationKey memory eukey = UndelegationKey({
            owner: address(0),
            token: address(0),
            consensus: address(0),
            validator: address(0),
            amount: 0,
            maturity: 0
        });
        emit Undelegating(key, 25, "", true, eukey, -1);
        (bool success, UndelegationKey memory ukey, ) = (overload.undelegating(key, 25, "", true));
        assertTrue(success);
        assertEq(ukey.owner, address(0));
        assertEq(ukey.token, address(0));
        assertEq(ukey.consensus, address(0));
        assertEq(ukey.validator, address(0));
        assertEq(ukey.amount, 0);
        assertEq(ukey.maturity, 0);

        assertTrue(overload.delegated(address(0xBEEF), address(token), address(0xCCCC)));
        assertEq(overload.getDelegationsLength(address(0xBEEF), address(token)), 1);
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).consensus, address(0xCCCC));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).validator, address(0xFFFF));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).amount, 25);

        assertEq(overload.balanceOf(address(0xBEEF), address(token).convertToId()), 75);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 25);

        vm.prank(address(0xBEEF));
        (success, ukey, ) = (overload.undelegating(key, 25, "", true));

        assertFalse(overload.delegated(address(0xBEEF), address(token), address(0xCCCC)));
        assertEq(overload.getDelegationsLength(address(0xBEEF), address(token)), 0);
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).consensus, address(0));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).validator, address(0));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).amount, 0);

        assertEq(overload.balanceOf(address(0xBEEF), address(token).convertToId()), 100);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 0);
    }

    function test_undelegating_withDelay() public {
        setDelay(address(0xCCCC), 500);

        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 50, true);

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xCCCC),
            validator: address(0xFFFF)
        });
        vm.prank(address(0xBEEF));
        (bool success, UndelegationKey memory ukey, ) = (overload.undelegating(key, 25, "", true));
        assertTrue(success);
        assertEq(ukey.owner, address(0xBEEF));
        assertEq(ukey.token, address(token));
        assertEq(ukey.consensus, address(0xCCCC));
        assertEq(ukey.validator, address(0xFFFF));
        assertEq(ukey.amount, 25);
        assertEq(ukey.maturity, 501);

        assertTrue(overload.delegated(address(0xBEEF), address(token), address(0xCCCC)));
        assertEq(overload.getDelegationsLength(address(0xBEEF), address(token)), 1);
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).consensus, address(0xCCCC));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).validator, address(0xFFFF));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).amount, 25);

        assertEq(overload.balanceOf(address(0xBEEF), address(token).convertToId()), 50);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 50);
    }

    function test_undelegating_whenMultipleDelegationsExist() public {
        setDelay(address(0xC), 500);

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

        // Undelegating
        undelegating(tokenB, address(0xBEEF), address(0xC), address(0x3), 50, true);

        // Assert
        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(tokenB),
            consensus: address(0xC),
            validator: address(0x3)
        });
        assertEq(overload.getDelegationsLength(address(0xBEEF), address(tokenB)), 6);
        assertEq(overload.getDelegation(key).consensus, address(0xC));
        assertEq(overload.getDelegation(key).validator, address(0x3));
        assertEq(overload.getDelegation(key).amount, 50);

        assertEq(overload.getUndelegationLength(address(0xBEEF), address(tokenB)), 1);
    }

    function test_undelegating_multipleUndelegationsWithDuplicates() public {
        setDelay(address(0xA), 500);
        setDelay(address(0xB), 500);
        setDelay(address(0xC), 500);

        deposit(tokenA, address(0xBEEF), 100);

        delegate(tokenA, address(0xBEEF), address(0xA), address(0x1), 100, true);
        delegate(tokenA, address(0xBEEF), address(0xB), address(0x2), 100, true);
        delegate(tokenA, address(0xBEEF), address(0xC), address(0x3), 100, true);
        delegate(tokenA, address(0xBEEF), address(0xD), address(0x4), 100, true);
        delegate(tokenA, address(0xBEEF), address(0xE), address(0x1), 100, true);
        delegate(tokenA, address(0xBEEF), address(0xF), address(0x1), 100, true);

        undelegating(tokenA, address(0xBEEF), address(0xA), address(0x1), 10, true);
        undelegating(tokenA, address(0xBEEF), address(0xA), address(0x1), 10, true);
        undelegating(tokenA, address(0xBEEF), address(0xA), address(0x1), 10, true);
        undelegating(tokenA, address(0xBEEF), address(0xB), address(0x2), 10, true);
        undelegating(tokenA, address(0xBEEF), address(0xB), address(0x2), 10, true);
        undelegating(tokenA, address(0xBEEF), address(0xC), address(0x3), 10, true);

        assertEq(overload.getUndelegationLength(address(0xBEEF), address(tokenA)), 6);
    }

    function test_fail_undelegating_nonExistentDelegation() public {
        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xCCCC),
            validator: address(0xFFFF)
        });
        vm.prank(address(0xBEEF));
        vm.expectRevert(EOverload.NotDelegated.selector);
        overload.undelegating(key, 1, "", true);
    }

    // Should fail when (owner, token, consensus) is correct, but the `validator`is not.
    function test_fail_undelegating_delegationNotFound() public {
        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);
        vm.expectRevert(DelegationLib.DelegationNotFound.selector);
        undelegating(address(0xBEEF), address(0xCCCC), address(0x1234), 50, true);
    }

    function test_fail_undelegating_overflow() public {
        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);
        vm.expectRevert(EOverload.Overflow.selector);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 101, true);

        setDelay(address(0xCCCC), 500);
        vm.expectRevert(EOverload.Overflow.selector);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 101, true);
    }

    function test_fail_undelegating_jailed() public {
        // Need to increase this as contract does not take low default `block.timestamp` into account
        vm.warp(1_000_000);

        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);

        vm.prank(address(0xCCCC));
        overload.jail(address(0xFFFF), 1 days);
        vm.expectRevert(EOverload.Jailed.selector);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);

        // After jailtime passed
        vm.warp(1_000_000 + 1 days - 1);
        vm.expectRevert(EOverload.Jailed.selector);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);
        vm.warp(1_000_000 + 1 days);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);
    }

    function test_fail_delegate_notOperator() public {
        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xCCCC),
            validator: address(0xFFFF)
        });
        vm.prank(address(0xABCD));
        vm.expectRevert(EOverload.Unauthorized.selector);
        overload.undelegating(key, 50, "", true);
    }

    function test_fail_undelegating_zero() public {
        vm.expectRevert(EOverload.Zero.selector);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 0, true);
    }

    function test_fail_undelegating_maxUndelegations() public {
        setDelay(address(0xCCCC), 500);
        deposit(address(0xBEEF), 1e18);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 1e18, true);

        for (uint256 i = 0; i < 256; i++) {
            undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 10, true);
        }

        vm.expectRevert(EOverload.MaxUndelegationsReached.selector);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 10, true);
    }

    /*//////////////////////////////////////////////////////////////
                               UNDELEGATE
    //////////////////////////////////////////////////////////////*/

    function test_undelegate() public {
        setDelay(address(0xCCCC), 500);
        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);

        assertEq(overload.balanceOf(address(0xBEEF), address(token).convertToId()), 0);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 100);

        (, UndelegationKey memory ukey, int256 index) = undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 50, true);

        // The bonded is still the same here.
        // `balanceOf` + `bonded` needs to always equal the principal token amount.
        assertEq(overload.balanceOf(address(0xBEEF), address(token).convertToId()), 0);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 100);

        vm.warp(501);
        undelegate(address(0xBEEF), ukey, index, "", true);

        assertEq(overload.balanceOf(address(0xBEEF), address(token).convertToId()), 50);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 50);
    }

    function test_undelegate_noIndex() public {
        setDelay(address(0xCCCC), 500);
        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);
        (, UndelegationKey memory ukey, ) = undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 50, true);

        vm.warp(501);
        undelegate(address(0xBEEF), ukey, int256(-1), "", true);
    }

    function test_fail_undelegate_nonMaturedDelegation() public {
        setDelay(address(0xCCCC), 500);
        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);
        (, UndelegationKey memory ukey, ) = undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 50, true);

        vm.warp(500);
        vm.expectRevert(EOverload.NonMatureUndelegation.selector);
        undelegate(address(0xBEEF), ukey, int256(-1), "", true);
    }

    function test_fail_undelegate_indexOutOfBounds() public {
        setDelay(address(0xCCCC), 500);
        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);
        (, UndelegationKey memory ukey, ) = undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 50, true);

        vm.expectRevert(stdError.indexOOBError);
        undelegate(address(0xBEEF), ukey, int256(1000), "", true);
    }

    function test_fail_undelegate_undelegationNotFound() public {
        setDelay(address(0xCCCC), 500);
        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 1, true);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 1, true);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 1, true);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 1, true);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 1, true);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 1, true);

        UndelegationKey memory ukey = UndelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xCCCC),
            validator: address(0xFFFF),
            amount: 1,
            maturity: 1
        });
        vm.expectRevert(UndelegationLib.UndelegationNotFound.selector);
        undelegate(address(0xBEEF), ukey, int256(-1), "", true);
    }

    /*//////////////////////////////////////////////////////////////
                                  JAIL
    //////////////////////////////////////////////////////////////*/

    function test_jail() public {
        // Need to increase this as contract does not take low default `block.timestamp` into account
        vm.warp(1_000_000);

        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);

        vm.prank(address(0xCCCC));
        vm.expectEmit(true, true, true, true);
        emit Jail(address(0xCCCC), address(0xFFFF), 1 hours, block.timestamp + 1 hours);
        overload.jail(address(0xFFFF), 1 hours);
        vm.expectRevert(EOverload.Jailed.selector);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);

        // After jailtime passed
        vm.warp(1_000_000 + 1 hours - 1);
        vm.expectRevert(EOverload.Jailed.selector);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);
        vm.warp(1_000_000 + 1 hours);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);
    }

    function test_jail_otherValidatorsFine() public {
        vm.warp(1_000_000);

        // Delegate
        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(0xCCCC), address(0x1234), 100, true);

        // Jail
        vm.prank(address(0xCCCC));
        vm.expectRevert(EOverload.Zero.selector);
        overload.jail(address(0xFFFF), 0);

        // Try undelegating successfully
        undelegating(address(0xBEEF), address(0xCCCC), address(0x1234), 100, true);
    }
    
    function test_jail_zero() public {
        vm.warp(1_000_000);

        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);

        // Jail zero
        vm.prank(address(0xCCCC));
        vm.expectRevert(EOverload.Zero.selector);
        overload.jail(address(0xFFFF), 0);

        // Try undelegating successfully
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);
    }

    function test_fail_jail_valueExceedsMaxJailtime() public {
        vm.warp(1_000_000);

        vm.prank(address(0xCCCC));
        vm.expectRevert(EOverload.ValueExceedsMaxJailtime.selector);
        overload.jail(address(0xFFFF), 7 days + 1);
    }

    function test_fail_jail_jailOnCooldown() public {
        // Need to increase this as contract does not take low default `block.timestamp` into account
        vm.warp(1_000_000);

        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);

        vm.prank(address(0xCCCC));
        overload.jail(address(0xFFFF), 1 hours);
        vm.expectRevert(EOverload.Jailed.selector);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);

        // After jailtime passed
        vm.warp(block.timestamp + 1 hours - 1);
        vm.expectRevert(EOverload.Jailed.selector);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);
        vm.warp(block.timestamp + 1 hours);
        undelegating(address(0xBEEF), address(0xCCCC), address(0xFFFF), 100, true);

        // Jail should fail as it's on cooldown
        vm.prank(address(0xCCCC));
        vm.expectRevert(EOverload.JailOnCooldown.selector);
        overload.jail(address(0xFFFF), 1 hours);

        vm.warp(block.timestamp + 23 hours);
        overload.jail(address(0xFFFF), 1 hours);
    }
}
