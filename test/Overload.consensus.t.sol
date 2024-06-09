// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Test, console, console2, stdError} from "forge-std/Test.sol";

import {DelegationKey} from "../src/libraries/types/Delegation.sol";
import {UndelegationKey} from "../src/libraries/types/Undelegation.sol";
import {FunctionCallLib} from "../src/libraries/FunctionCallLib.sol";
import {HookCallLib} from "../src/libraries/HookCallLib.sol";
import {TokenIdLib} from "../src/libraries/TokenIdLib.sol";
import {Overload} from "../src/Overload.sol";

import {ConsensusMirror} from "./mocks/avs/ConsensusMirrorMock.sol";
import {
    ConsensusHookParametersMock,
    ConsensusRevertDelegateMock,
    ConsensusRevertRedelegateMock,
    ConsensusRevertUndelegatingMock,
    ConsensusRevertUndelegateMock,
    ConsensusNoHook,
    ConsensusNoERC165Interface,
    ConsensusWhenERC165InterfaceReverts,
    ConsensusWrongReturnValueOnHook,
    ConsensusInsufficientGasBudget,
    ConsensusGasEater
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
    ConsensusMirror public consensusMirror;
    ConsensusHookParametersMock public consensusHookParametersMock;
    ConsensusRevertDelegateMock public consensusRevert;
    ConsensusRevertRedelegateMock public consensusRevertRedelegateMock;
    ConsensusRevertUndelegatingMock public consensusRevertUndelegating;
    ConsensusRevertUndelegateMock public consensusRevertUndelegateMock;
    ConsensusNoHook public consensusNoHook;
    ConsensusNoERC165Interface public consensusNoERC165Interface;
    ConsensusWhenERC165InterfaceReverts public consensusWhenERC165InterfaceReverts;
    ConsensusWrongReturnValueOnHook public consensusWrongReturnValueOnHook;
    ConsensusInsufficientGasBudget public consensusInsufficientGasBudget;
    ConsensusGasEater public consensusGasEater;

    function setUp() public {
        overload = new Overload();
        token = new ERC20Mock("Test", "TEST", 18);
        consensusMirror = new ConsensusMirror(address(overload));
        consensusHookParametersMock = new ConsensusHookParametersMock(address(overload), address(token));
        consensusRevert = new ConsensusRevertDelegateMock(address(overload));
        consensusRevertRedelegateMock = new ConsensusRevertRedelegateMock(address(overload));
        consensusRevertUndelegating = new ConsensusRevertUndelegatingMock(address(overload));
        consensusRevertUndelegateMock = new ConsensusRevertUndelegateMock(address(overload));
        consensusNoHook = new ConsensusNoHook();
        consensusNoERC165Interface = new ConsensusNoERC165Interface();
        consensusWhenERC165InterfaceReverts = new ConsensusWhenERC165InterfaceReverts();
        consensusWrongReturnValueOnHook = new ConsensusWrongReturnValueOnHook();
        consensusInsufficientGasBudget = new ConsensusInsufficientGasBudget();
        consensusGasEater = new ConsensusGasEater();
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
        overload.delegate(key, -1, amount, "", strict);
    }

    function delegate(ERC20Mock token_, address user, address consensus, address validator, uint256 amount, bool strict) public {
        DelegationKey memory key = DelegationKey({
            owner: user,
            token: address(token_),
            consensus: consensus,
            validator: validator
        });

        vm.prank(user);
        overload.delegate(key, -1, amount, "", strict);
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
        return overload.redelegate(fromKey, toKey, -1, "", strict);
    }

    function undelegating(address user, address consensus, address validator, uint256 amount, bool strict) public returns (bool success, UndelegationKey memory, int256) {
        DelegationKey memory key = DelegationKey({
            owner: user,
            token: address(token),
            consensus: consensus,
            validator: validator
        });

        vm.prank(user);
        return overload.undelegating(key, -1, amount, "", strict);
    }

    function undelegating(ERC20Mock token_, address user, address consensus, address validator, uint256 amount, bool strict) public returns (bool success, UndelegationKey memory, int256) {
        DelegationKey memory key = DelegationKey({
            owner: user,
            token: address(token_),
            consensus: consensus,
            validator: validator
        });

        vm.prank(user);
        return overload.undelegating(key, -1, amount, "", strict);
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
                    CONSENSUS WITH MIRRORED BALANCE
    //////////////////////////////////////////////////////////////*/

    function test_delegate_consensusMirror() public {
        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(consensusMirror), address(0xFFFF), 100, true);
        deposit(address(0xABCD), 100);
        delegate(address(0xABCD), address(consensusMirror), address(0xFFFF), 100, true);

        assertEq(consensusMirror.getBalance(address(0xBEEF), address(token)), 100);
        assertEq(consensusMirror.getValidator(address(0xFFFF), address(token)), 200);
        assertEq(consensusMirror.getPool(address(token)), 200);

        undelegating(address(0xBEEF), address(consensusMirror), address(0xFFFF), 50, true);

        assertEq(consensusMirror.getBalance(address(0xBEEF), address(token)), 50);
        assertEq(consensusMirror.getValidator(address(0xFFFF), address(token)), 150);
        assertEq(consensusMirror.getPool(address(token)), 150);
    }

    /*//////////////////////////////////////////////////////////////
                       CONSENSUS HOOK PARAMETERS
    //////////////////////////////////////////////////////////////*/

    function test_hookParameters() public {
        setDelay(address(consensusHookParametersMock), 500);
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
        overload.delegate(key, -1, 100, hex"42", true);

        // Redelegate
        vm.prank(address(0xBEEF));
        overload.redelegate(key, toKey, -1, hex"42", true);

        // Undelegating
        vm.prank(address(0xBEEF));
        (, UndelegationKey memory ukey, ) = overload.undelegating(toKey, -1, 100, hex"42", true);
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
        overload.delegate(key, -1, 50, "", true);
        assertEq(overload.getDelegationsLength(address(0xBEEF), address(token)), 0);

        // Strict false passes
        vm.prank(address(0xBEEF));
        overload.delegate(key, -1, 50, "", false);
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
        overload.undelegating(key, -1, 25, "", true);

        // hould not revert
        vm.prank(address(0xBEEF));
        overload.undelegating(key, -1, 25, "", false);
    }

    function test_fail_undelegate_consensusRevert() public {
        setDelay(address(consensusRevertUndelegateMock), 500);
        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(consensusRevertUndelegateMock), address(0xFFFF), 100, true);

        assertEq(overload.balanceOf(address(0xBEEF), address(token).convertToId()), 0);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 100);

        (, UndelegationKey memory ukey, int256 index) = undelegating(address(0xBEEF), address(consensusRevertUndelegateMock), address(0xFFFF), 50, true);

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
        setDelay(address(consensusNoHook), 500);
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
        (, UndelegationKey memory ukey, int256 index) = undelegating(address(0xBEEF), address(consensusNoHook), address(0xFFFF), 100, false);

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

    /*//////////////////////////////////////////////////////////////
                     CONSENSUS NO ERC165 INTERFACE
    //////////////////////////////////////////////////////////////*/

    function test_delegate_noERC165Interface() public {
        deposit(address(0xBEEF), 100);
        delegate(address(0xBEEF), address(consensusNoERC165Interface), address(0xFFFF), 100, false);
    }

    /*//////////////////////////////////////////////////////////////
                   CONSENSUS ERC165 INTERFACE REVERTS
    //////////////////////////////////////////////////////////////*/

    function test_delegate_erc165InterfaceReverts() public {
        deposit(address(0xBEEF), 100);

        // Does not revert even when `strict` is `true`, because of the logic in OZ's `ERC165Checker` library.
        delegate(address(0xBEEF), address(consensusWhenERC165InterfaceReverts), address(0xFFFF), 100, true);
    }

    /*//////////////////////////////////////////////////////////////
                  CONSENSUS WRONG RETURN VALUE ON HOOK
    //////////////////////////////////////////////////////////////*/

    function test_delegate_consensusWrongReturnValueOnHook() public {
        deposit(address(0xBEEF), 100);

        vm.expectRevert(HookCallLib.InvalidHookResponse.selector);
        delegate(address(0xBEEF), address(consensusWrongReturnValueOnHook), address(0xFFFF), 100, true);
    }

    /*//////////////////////////////////////////////////////////////
                    CONSENSUS INSUFFICENT GAS BUDGET
    //////////////////////////////////////////////////////////////*/

    function test_fail_delegate_gasBelowGasBudget() public {
        deposit(address(0xBEEF), 100);

        // Should revert
        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(consensusInsufficientGasBudget),
            validator: address(0xFFFF)
        });
        vm.prank(address(0xBEEF));
        vm.expectRevert(abi.encodeWithSelector(FunctionCallLib.InsufficientGas.selector, 1048480));
        overload.delegate{gas: 2 ** 20 + 29550}(key, -1, 100, "", false);

        // // Should not revert
        // vm.prank(address(0xBEEF));
        // overload.delegate{gas: 2 ** 20 + 29045}(key, 100, "", false);
    }

    /*//////////////////////////////////////////////////////////////
                  CONSENSUS REVERT ABOVE 1M GAS USAGE
    //////////////////////////////////////////////////////////////*/

    function test_delegate_consensusGasEater() public {
        deposit(address(0xBEEF), 100);

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(consensusGasEater),
            validator: address(0xFFFF)
        });

        // Reverts
        uint256 gasLeft = gasleft();
        vm.prank(address(0xBEEF));
        vm.expectRevert(FunctionCallLib.FailedCall.selector);
        overload.delegate(key, -1, 100, abi.encodePacked(uint256(49)), true);
        console2.log(gasLeft - gasleft());

        // Does not revert
        gasLeft = gasleft();
        vm.prank(address(0xBEEF));
        overload.delegate(key, -1, 50, abi.encodePacked(uint256(48)), true);
        console2.log(gasLeft - gasleft());

        // Does not revert, because strict is false
        gasLeft = gasleft();
        vm.prank(address(0xBEEF));
        overload.delegate(key, -1, 50, abi.encodePacked(uint256(100)), false);
        console2.log(gasLeft - gasleft());

        assertEq(consensusGasEater.slots(47), 47);
        assertEq(consensusGasEater.slots(48), 0);
        assertEq(consensusGasEater.slots(50), 0);
        assertEq(consensusGasEater.slots(100), 0);
    }
}
