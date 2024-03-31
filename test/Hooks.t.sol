// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import "./mocks/ConsensusMock.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

import {Overload} from "../src/Overload.sol";
import {Hooks} from "../src/libraries/Hooks.sol";

contract HooksTest is Test {
    ERC20Mock token;
    Overload public overload;

    ConsensusWithBeforeHook public consensusWithBeforeHook;
    ConsensusRevertHook public consensusRevertHook;
    ConsensusNoHook public consnesusNoHook;
    ConsensusNoSupportInterface public consensusNoSupportInterface;
    ConsensusSupportInterfaceRevert public consensusSupportInterfaceRevert;

    function overloadDeposit(address owner, address token_, uint256 amount) public {
        ERC20Mock(token_).mint(owner, amount);

        vm.prank(owner);
        token.approve(address(overload), type(uint256).max);

        vm.prank(owner);
        overload.deposit(owner, token_, amount);
    }

    function setUp() public {
        token = new ERC20Mock("Test", "TEST", 18);
        overload = new Overload();

        consensusWithBeforeHook = new ConsensusWithBeforeHook();
        consensusRevertHook = new ConsensusRevertHook();
        consnesusNoHook = new ConsensusNoHook();
        consensusNoSupportInterface = new ConsensusNoSupportInterface();
        consensusSupportInterfaceRevert = new ConsensusSupportInterfaceRevert();
    }

    /*//////////////////////////////////////////////////////////////
                          TEST BEFORE_DELEGATE
    //////////////////////////////////////////////////////////////*/

    function test_beforeDelegate_whenConsensusAddrZero() public {
        overloadDeposit(address(0xBEEF), address(token), 100);

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0),
            validator: address(0xABCD)
        });

        vm.prank(address(0xBEEF));
        overload.delegate(key, 10, "", false);
        vm.prank(address(0xBEEF));
        overload.delegate(key, 10, "", true);
    }

    function test_beforeDelegate_noSupportInterface() public {
        overloadDeposit(address(0xBEEF), address(token), 100);

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(consensusNoSupportInterface),
            validator: address(0xABCD)
        });

        vm.prank(address(0xBEEF));
        overload.delegate(key, 10, "", false);
    
        vm.prank(address(0xBEEF));
        overload.delegate(key, 10, "", true);
    }

    function test_beforeDelegate_whenSupportInterfaceReverts() public {
        overloadDeposit(address(0xBEEF), address(token), 100);

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(consensusSupportInterfaceRevert),
            validator: address(0xABCD)
        });

        vm.prank(address(0xBEEF));
        overload.delegate(key, 10, "", false);
    
        vm.prank(address(0xBEEF));
        overload.delegate(key, 10, "", true);
    }

    function test_beforeDelegate_whenHookDoesNotExist() public {
        overloadDeposit(address(0xBEEF), address(token), 100);

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(consnesusNoHook),
            validator: address(0xABCD)
        });

        vm.prank(address(0xBEEF));
        overload.delegate(key, 10, "", false);
    
        vm.prank(address(0xBEEF));
        vm.expectRevert();
        overload.delegate(key, 10, "", true);
    }

    function test_beforeDelegate_whenHookReverts() public {
        overloadDeposit(address(0xBEEF), address(token), 100);

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(consensusRevertHook),
            validator: address(0xABCD)
        });

        vm.prank(address(0xBEEF));
        overload.delegate(key, 10, "", false);
    
        vm.prank(address(0xBEEF));
        vm.expectRevert();
        overload.delegate(key, 10, "", true);
    }

    function test_beforeDelegate_withHook() public {
        overloadDeposit(address(0xBEEF), address(token), 100);

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(consensusWithBeforeHook),
            validator: address(0xABCD)
        });

        assertEq(consensusWithBeforeHook.counter(), 0);
        vm.prank(address(0xBEEF));
        overload.delegate(key, 10, "", true);
        assertEq(consensusWithBeforeHook.counter(), 1);

        vm.prank(address(0xBEEF));
        overload.delegate(key, 10, "", true);
        assertEq(consensusWithBeforeHook.counter(), 2);
    }
}
