// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

import {Overload} from "../src/Overload.sol";
import {Delegation, DelegationKey} from "../src/libraries/types/Delegation.sol";
import {UndelegationKey} from "../src/libraries/types/Undelegation.sol";

contract OverloadTest is Test {
    ERC20Mock token;
    Overload overload;

    mapping(address => mapping(uint256 => uint256)) public userMintAmounts;
    mapping(address => mapping(uint256 => uint256)) public userTransferOrBurnAmounts;

    function setUp() public {
        token = new ERC20Mock("Test", "TEST", 18);
        overload = new Overload();
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function deposit(address owner, address token_, uint256 amount) public {
        ERC20Mock(token_).mint(owner, amount);

        vm.prank(owner);
        token.approve(address(overload), type(uint256).max);

        vm.prank(owner);
        overload.deposit(owner, token_, amount);
    }

    function withdraw(address owner, address token_, uint256 amount, address recipient) public {
        vm.prank(owner);
        overload.withdraw(owner, token_, amount, recipient);
    }

    /*//////////////////////////////////////////////////////////////
                             TEST OVERLOAD
    //////////////////////////////////////////////////////////////*/

    function test_deposit() public {
        deposit(address(0xBEEF), address(token), 100);

        assertEq(overload.unbonded(address(0xBEEF), address(token)), 100);
    }

    function test_delegate() public {
        deposit(address(0xBEEF), address(token), 100);

        vm.prank(address(0xBEEF));
        overload.delegate(DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xC0),
            validator: address(0xABCD)
        }), 70, "", false);

        (address consensus, address validator, uint256 amount) = overload.delegations(address(0xBEEF), address(token), 0);
        assertEq(consensus, address(0xC0));
        assertEq(validator, address(0xABCD));
        assertEq(amount, 70);
        assertEq(overload.getDelegationCardinality(address(0xBEEF), address(token)), 1);

        assertEq(overload.unbonded(address(0xBEEF), address(token)), 30);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 70);
    }

    function test_delegateIncrease() public {
        deposit(address(0xBEEF), address(token), 100);

        vm.prank(address(0xBEEF));
        overload.delegate(DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xC0),
            validator: address(0xABCD)
        }), 70, "", false);

        vm.prank(address(0xBEEF));
        overload.delegate(DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xC0),
            validator: address(0xABCD)
        }), 10, "", false);

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xC0),
            validator: address(0xABCD)
        });

        assertEq(overload.getDelegation(key).consensus, address(0xC0));
        assertEq(overload.getDelegation(key).validator, address(0xABCD));
        assertEq(overload.getDelegation(key).amount, 80);

        assertEq(overload.unbonded(address(0xBEEF), address(token)), 20);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 80);
    }

    function test_delegateMultiple() public {
        /**
         * Setup
         */

        deposit(address(0xBEEF), address(token), 100);

        vm.prank(address(0xBEEF));
        overload.delegate(DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xC0),
            validator: address(0xABCD)
        }), 70, "", false);

        vm.prank(address(0xBEEF));
        overload.delegate(DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xC1),
            validator: address(0xABCD)
        }), 50, "", false);

        /**
         * Checks
         */

        DelegationKey memory key;

        key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xC0),
            validator: address(0xABCD)
        });
        assertEq(overload.getDelegation(key).consensus, address(0xC0));
        assertEq(overload.getDelegation(key).validator, address(0xABCD));
        assertEq(overload.getDelegation(key).amount, 70);

        key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xC1),
            validator: address(0xABCD)
        });
        assertEq(overload.getDelegation(key).consensus, address(0xC1));
        assertEq(overload.getDelegation(key).validator, address(0xABCD));
        assertEq(overload.getDelegation(key).amount, 50);

        assertEq(overload.getDelegationCardinality(address(0xBEEF), address(token)), 2);
        assertEq(overload.unbonded(address(0xBEEF), address(token)), 30);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 70);

        // ===

        vm.prank(address(0xBEEF));
        overload.delegate(key, 45, "", false);

        assertEq(overload.getDelegation(key).consensus, address(0xC1));
        assertEq(overload.getDelegation(key).validator, address(0xABCD));
        assertEq(overload.getDelegation(key).amount, 95);
        assertEq(overload.unbonded(address(0xBEEF), address(token)), 5);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 95);
    }

    function test_undelegatingNoCooldown() public {
        deposit(address(0xBEEF), address(token), 100);
        vm.prank(address(0xBEEF));
        overload.delegate(
            DelegationKey({
                owner: address(0xBEEF),
                token: address(token),
                consensus: address(0xC0),
                validator: address(0xABCD)
            }),
            50,
            "",
            false
        );

        vm.prank(address(0xBEEF));
        overload.undelegating(
            DelegationKey({
                owner: address(0xBEEF),
                token: address(token),
                consensus: address(0xC0),
                validator: address(0xABCD)
            }),
            25,
            ""
        );

        assertEq(overload.unbonded(address(0xBEEF), address(token)), 75);
        assertEq(overload.bonded(address(0xBEEF), address(token)), 25);
    }

    function test_undelegatingWithCooldown() public {
        deposit(address(0xBEEF), address(token), 100);
        vm.prank(address(0xBEEF));
        overload.delegate(
            DelegationKey({
                owner: address(0xBEEF),
                token: address(token),
                consensus: address(0xC0),
                validator: address(0xABCD)
            }),
            50,
            "",
            false
        );

        vm.prank(address(0xC0));
        overload.setCooldown(address(0xC0), 1000);
        vm.prank(address(0xBEEF));
        (, UndelegationKey memory key) = overload.undelegating(
            DelegationKey({
                owner: address(0xBEEF),
                token: address(token),
                consensus: address(0xC0),
                validator: address(0xABCD)
            }),
            25,
            ""
        );

        assertEq(overload.getUndelegation(key).consensus, address(0xC0));
        assertEq(overload.getUndelegation(key).validator, address(0xABCD));
        assertEq(overload.getUndelegation(key).amount, 25);
        assertEq(overload.getUndelegation(key).completion, block.timestamp + 1000);
    }

    function test_undelegatingFull() public {
        deposit(address(0xBEEF), address(token), 100);
        vm.prank(address(0xBEEF));
        overload.delegate(
            DelegationKey({
                owner: address(0xBEEF),
                token: address(token),
                consensus: address(0xC0),
                validator: address(0xABCD)
            }),
            50,
            "",
            false
        );

        vm.prank(address(0xC0));
        overload.setCooldown(address(0xC0), 1000);

        vm.prank(address(0xBEEF));
        overload.undelegating(
            DelegationKey({
                owner: address(0xBEEF),
                token: address(token),
                consensus: address(0xC0),
                validator: address(0xABCD)
            }),
            50,
            ""
        );

        assertEq(overload.getDelegationCardinality(address(0xBEEF), address(token)), 0);
        assertEq(overload.getUndelegationCardinality(address(0xBEEF), address(token)), 1);
    }

    function test_undelegatingWithMany() public {
        deposit(address(0xBEEF), address(token), 1e18);

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(0xC0),
            validator: address(0xABCD)
        });

        vm.prank(address(0xBEEF));
        key.consensus = address(0xC0);
        overload.delegate(key, 50, "", false);

        vm.prank(address(0xBEEF));
        key.consensus = address(0xC1);
        overload.delegate(key, 50, "", false);

        vm.prank(address(0xBEEF));
        key.consensus = address(0xC2);
        overload.delegate(key, 50, "", false);

        vm.prank(address(0xBEEF));
        key.consensus = address(0xC3);
        overload.delegate(key, 50, "", false);

        vm.prank(address(0xBEEF));
        key.consensus = address(0xC4);
        overload.delegate(key, 50, "", false);

        vm.prank(address(0xBEEF));
        key.consensus = address(0xC5);
        overload.delegate(key, 50, "", false);

        vm.prank(address(0xBEEF));
        key.consensus = address(0xC6);
        overload.delegate(key, 50, "", false);

        vm.prank(address(0xBEEF));
        key.consensus = address(0xC7);
        overload.delegate(key, 50, "", false);

        vm.prank(address(0xBEEF));
        key.consensus = address(0xC8);
        overload.delegate(key, 50, "", false);

        vm.prank(address(0xBEEF));
        key.consensus = address(0xC9);
        overload.delegate(key, 50, "", false);

        vm.prank(address(0xBEEF));
        key.consensus = address(0xC10);
        overload.delegate(key, 50, "", false);

        // ===

        vm.prank(address(0xC31));
        overload.setCooldown(address(0xC31), 1000);

        vm.prank(address(0xBEEF));
        overload.undelegating(key, 25, "");
    }

    function test_undelegate() public {
        deposit(address(0xBEEF), address(token), 100);
        vm.prank(address(0xBEEF));
        overload.delegate(
            DelegationKey({
                owner: address(0xBEEF),
                token: address(token),
                consensus: address(0xC0),
                validator: address(0xABCD)
            }),
            50,
            "",
            false
        );

        vm.prank(address(0xC0));
        overload.setCooldown(address(0xC0), 1000);

        vm.prank(address(0xBEEF));
        (, UndelegationKey memory key) = overload.undelegating(
            DelegationKey({
                owner: address(0xBEEF),
                token: address(token),
                consensus: address(0xC0),
                validator: address(0xABCD)
            }),
            50,
            ""
        );

        // ===

        vm.warp(block.timestamp + 1000);
        vm.prank(address(0xBEEF));
        overload.undelegate(key);
    }

    function test_flush() public {
        deposit(address(0xBEEF), address(token), 100);

        vm.prank(address(0xBEEF));
        overload.delegate(
            DelegationKey({
                owner: address(0xBEEF),
                token: address(token),
                consensus: address(0xC0),
                validator: address(0xABCD)
            }),
            50,
            "",
            false
        );

        vm.prank(address(0xC0));
        overload.setCooldown(address(0xC0), 1000);

        vm.prank(address(0xBEEF));
        overload.undelegating(
            DelegationKey({
                owner: address(0xBEEF),
                token: address(token),
                consensus: address(0xC0),
                validator: address(0xABCD)
            }),
            30,
            ""
        );
        vm.warp(block.timestamp + 1000);
        vm.prank(address(0xBEEF));
        overload.undelegating(
            DelegationKey({
                owner: address(0xBEEF),
                token: address(token),
                consensus: address(0xC0),
                validator: address(0xABCD)
            }),
            20,
            ""
        );
        vm.warp(block.timestamp + 999);

        vm.prank(address(0xBEEF));
        (uint256 success, uint256 failure) = overload.flush(address(0xBEEF), address(token));
        assertEq(success, 1);
        assertEq(failure, 1);
    }
}
