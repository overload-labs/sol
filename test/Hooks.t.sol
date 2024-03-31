// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

import {IOverloadHooks} from "../src/interfaces/IOverloadHooks.sol";
import {Overload} from "../src/Overload.sol";
import {DelegationKey} from "../src/libraries/types/Delegation.sol";
import {Hooks} from "../src/libraries/Hooks.sol";

contract ConsensusWithHook {
    uint256 public counter = 0;

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == IOverloadHooks.beforeDelegate.selector;
    }

    function beforeDelegate(address, DelegationKey memory, uint256, bytes calldata) external returns (bytes4) {
        counter = 1;

        return IOverloadHooks.beforeDelegate.selector;
    }
}

contract ConsensusRevertHook {
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == IOverloadHooks.beforeDelegate.selector;
    }

    function beforeDelegate(address, DelegationKey memory, uint256, bytes calldata) external pure returns (bytes4) {
        revert();
    }
}

contract ConsensusNoHook {
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == IOverloadHooks.beforeDelegate.selector;
    }
}

contract HooksTest is Test {
    ERC20Mock token;
    Overload public overload;

    ConsensusWithHook public consensusWithHook;
    ConsensusRevertHook public consensusRevertHook;
    ConsensusNoHook public consnesusNoHook;

    function setUp() public {
        token = new ERC20Mock("Test", "TEST", 18);
        overload = new Overload();

        consensusWithHook = new ConsensusWithHook();
        consensusRevertHook = new ConsensusRevertHook();
        consnesusNoHook = new ConsensusNoHook();
    }

    function test_beforeDelegate_shouldCallHook() public {
        token.mint(address(0xBEEF), 100);

        vm.prank(address(0xBEEF));
        token.approve(address(overload), type(uint256).max);

        vm.prank(address(0xBEEF));
        overload.deposit(address(0xBEEF), address(token), 100);

        assertEq(consensusWithHook.counter(), 0);

        vm.prank(address(0xBEEF));
        overload.delegate(
            DelegationKey({
                owner: address(0xBEEF),
                token: address(token),
                consensus: address(consensusWithHook),
                validator: address(0xABCD)
            }),
            100,
            ""
        );

        assertEq(consensusWithHook.counter(), 1);
    }

    function test_beforeDelegate_shouldNotFailOnRevert() public {
        token.mint(address(0xBEEF), 100);

        vm.prank(address(0xBEEF));
        token.approve(address(overload), type(uint256).max);

        vm.prank(address(0xBEEF));
        overload.deposit(address(0xBEEF), address(token), 100);

        vm.prank(address(0xBEEF));
        overload.delegate(
            DelegationKey({
                owner: address(0xBEEF),
                token: address(token),
                consensus: address(consensusRevertHook),
                validator: address(0xABCD)
            }),
            70,
            ""
        );
    }

    function test_beforeDelegate_shouldNotFailNoHook() public {
        token.mint(address(0xBEEF), 100);

        vm.prank(address(0xBEEF));
        token.approve(address(overload), type(uint256).max);

        vm.prank(address(0xBEEF));
        overload.deposit(address(0xBEEF), address(token), 100);

        vm.prank(address(0xBEEF));
        overload.delegate(
            DelegationKey({
                owner: address(0xBEEF),
                token: address(token),
                consensus: address(consnesusNoHook),
                validator: address(0xABCD)
            }),
            70,
            ""
        );
    }

    function test_beforeDelegate_shouldNotFailOnEmptyAddress() public {
        token.mint(address(0xBEEF), 100);

        vm.prank(address(0xBEEF));
        token.approve(address(overload), type(uint256).max);

        vm.prank(address(0xBEEF));
        overload.deposit(address(0xBEEF), address(token), 100);

        vm.prank(address(0xBEEF));
        overload.delegate(
            DelegationKey({
                owner: address(0xBEEF),
                token: address(token),
                consensus: address(0),
                validator: address(0xABCD)
            }),
            70,
            ""
        );
    }
}
