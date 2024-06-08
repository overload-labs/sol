// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Test, console, console2, stdError} from "forge-std/Test.sol";

import {DelegationNotFound, DelegationKey} from "../src/libraries/types/Delegation.sol";
import {UndelegationNotFound, UndelegationKey} from "../src/libraries/types/Undelegation.sol";
import {TokenIdLib} from "../src/libraries/TokenIdLib.sol";
import {Overload} from "../src/Overload.sol";

import {
    ConsensusHookParametersMock,
    ConsensusRevertDelegateMock,
    ConsensusRevertRedelegateMock,
    ConsensusRevertUndelegatingMock,
    ConsensusRevertUndelegateMock,
    ConsensusNoHook
} from "./mocks/ConsensusMock.sol";
import {ERC20Fee} from "./mocks/ERC20Fee.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract OverloadConsensusTest is Test {
    using TokenIdLib for uint256;
    using TokenIdLib for address;

    event Deposit(address indexed caller, address indexed owner, address indexed token, uint256 amount);
    event Withdraw(address indexed caller, address owner, address indexed token, uint256 amount, address recipient);

    Overload public overload;
    ERC20Mock public token;
    ConsensusHookParametersMock public consensusHookParametersMock;
    ConsensusRevertDelegateMock public consensusRevert;
    ConsensusRevertRedelegateMock public consensusRevertRedelegateMock;
    ConsensusRevertUndelegatingMock public consensusRevertUndelegating;
    ConsensusRevertUndelegateMock public consensusRevertUndelegateMock;
    ConsensusNoHook public consensusNoHook;

    function setUp() public {
        overload = new Overload();
        token = new ERC20Mock("Test", "TEST", 18);
        consensusHookParametersMock = new ConsensusHookParametersMock(address(overload), address(token));
        consensusRevert = new ConsensusRevertDelegateMock(address(overload));
        consensusRevertRedelegateMock = new ConsensusRevertRedelegateMock(address(overload));
        consensusRevertUndelegating = new ConsensusRevertUndelegatingMock(address(overload));
        consensusRevertUndelegateMock = new ConsensusRevertUndelegateMock(address(overload));
        consensusNoHook = new ConsensusNoHook();
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

    function redelegate(address user, address consensus, address fromValidator, address toValidator, bool strict) public returns (bool) {
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
        return overload.redelegate(fromKey, toKey, "", strict);
    }

    function undelegating(address user, address consensus, address validator, uint256 amount, bool strict) public returns (bool success, UndelegationKey memory, uint256) {
        DelegationKey memory key = DelegationKey({
            owner: user,
            token: address(token),
            consensus: consensus,
            validator: validator
        });

        vm.prank(user);
        return overload.undelegating(key, amount, "", strict);
    }

    function undelegating(ERC20Mock token_, address user, address consensus, address validator, uint256 amount, bool strict) public returns (bool success, UndelegationKey memory, uint256) {
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

    function setUndelegatingDelay(address consensus, uint256 delay) public {
        vm.prank(consensus);
        overload.setUndelegatingDelay(consensus, delay);
    }

    /*//////////////////////////////////////////////////////////////
                       CONSENSUS HOOK PARAMETERS
    //////////////////////////////////////////////////////////////*/

    function test_hookParameters() public {
        setUndelegatingDelay(address(consensusHookParametersMock), 500);
        deposit(address(0xBEEF), 100);

        // Base key
        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(consensusHookParametersMock),
            validator: address(0xFFFF)
        });
        // To key
        DelegationKey memory toKey = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(consensusHookParametersMock),
            validator: address(0xEEEE)
        });

        // Delegate
        vm.prank(address(0xBEEF));
        overload.delegate(key, 100, hex"42", true);

        // Redelegate
        vm.prank(address(0xBEEF));
        overload.redelegate(key, toKey, hex"42", true);

        // Undelegating
        vm.prank(address(0xBEEF));
        (, UndelegationKey memory ukey, uint256 index) = overload.undelegating(toKey, 100, hex"42", true);
        assertEq(overload.balanceOf(address(0xBEEF), address(token).convertToId()), 0);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 100);

        // Undelegate
        vm.warp(block.timestamp + 500);
        vm.prank(address(0xBEEF));
        overload.undelegate(ukey, int256(-1), hex"42", true);
        assertEq(overload.balanceOf(address(0xBEEF), address(token).convertToId()), 100);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSENSUS REVERT
    //////////////////////////////////////////////////////////////*/

    function test_fail_delegate_consensusRevert() public {
        deposit(address(0xBEEF), 100);

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(consensusRevert),
            validator: address(0xFFFF)
        });

        // Strict true reverts
        vm.prank(address(0xBEEF));
        vm.expectRevert();
        overload.delegate(key, 50, "", true);
        assertEq(overload.getDelegationsLength(address(0xBEEF), address(token)), 0);

        // Strict false passes
        vm.prank(address(0xBEEF));
        overload.delegate(key, 50, "", false);
        assertEq(overload.getDelegationsLength(address(0xBEEF), address(token)), 1);
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).consensus, address(consensusRevert));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).validator, address(0xFFFF));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).amount, 50);
    }

    function test_redelegate() public {
        deposit(address(0xBEEF), 1000);
        delegate(address(0xBEEF), address(consensusRevertRedelegateMock), address(0xFFFF), 50, true);

        // Should revert
        vm.expectRevert();
        redelegate(address(0xBEEF), address(consensusRevertRedelegateMock), address(0xFFFF), address(0xEEEE), true);

        // Should not revert
        redelegate(address(0xBEEF), address(consensusRevertRedelegateMock), address(0xFFFF), address(0xEEEE), false);
    }

    function test_fail_undelegating_consensusRevert() public {
        // Deposit and delegate
        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(consensusRevertUndelegating), address(0xFFFF), 50, true);

        // Undelegating
        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(consensusRevertUndelegating),
            validator: address(0xFFFF)
        });

        // Should revert
        vm.prank(address(0xBEEF));
        vm.expectRevert();
        overload.undelegating(key, 25, "", true);

        // hould not revert
        vm.prank(address(0xBEEF));
        overload.undelegating(key, 25, "", false);
    }

    function test_fail_undelegate_consensusRevert() public {
        setUndelegatingDelay(address(consensusRevertUndelegateMock), 500);
        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(consensusRevertUndelegateMock), address(0xFFFF), 100, true);

        assertEq(overload.balanceOf(address(0xBEEF), address(token).convertToId()), 0);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 100);

        (, UndelegationKey memory ukey, uint256 index) = undelegating(address(0xBEEF), address(consensusRevertUndelegateMock), address(0xFFFF), 50, true);

        // The bonded is still the same here.
        // `balanceOf` + `bonded` needs to always equal the principal token amount.
        assertEq(overload.balanceOf(address(0xBEEF), address(token).convertToId()), 0);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 100);

        // Should revert
        vm.warp(501);
        vm.expectRevert();
        undelegate(address(0xBEEF), ukey, int256(index), "", true);

        // Should not revert
        undelegate(address(0xBEEF), ukey, int256(index), "", false);

        assertEq(overload.balanceOf(address(0xBEEF), address(token).convertToId()), 50);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 50);
    }

    /*//////////////////////////////////////////////////////////////
                                NO HOOKS
    //////////////////////////////////////////////////////////////*/

    function test_fail_noHooks() public {
        setUndelegatingDelay(address(consensusNoHook), 500);
        deposit(address(0xBEEF), 100);

        // Should revert
        vm.expectRevert();
        delegate(address(0xBEEF), address(consensusNoHook), address(0xFFFF), 100, true);
        // Should not revert
        delegate(address(0xBEEF), address(consensusNoHook), address(0xFFFF), 100, false);

        assertEq(overload.balanceOf(address(0xBEEF), address(token).convertToId()), 0);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 100);

        // Should revert
        vm.expectRevert();
        undelegating(address(0xBEEF), address(consensusNoHook), address(0xFFFF), 100, true);
        // Should not revert
        (, UndelegationKey memory ukey, uint256 index) = undelegating(address(0xBEEF), address(consensusNoHook), address(0xFFFF), 100, false);

        assertEq(overload.balanceOf(address(0xBEEF), address(token).convertToId()), 0);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 100);

        vm.warp(block.timestamp + 500);
        // Should revert
        vm.expectRevert();
        undelegate(address(0xBEEF), ukey, int256(index), "", true);
        // Should not revert
        undelegate(address(0xBEEF), ukey, int256(index), "", false);

        assertEq(overload.balanceOf(address(0xBEEF), address(token).convertToId()), 100);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 0);
    }
}
