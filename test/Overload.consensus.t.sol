// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Test, console, console2, stdError} from "forge-std/Test.sol";

import {DelegationKey} from "../src/libraries/types/Delegation.sol";
import {TokenIdLib} from "../src/libraries/TokenIdLib.sol";
import {Overload} from "../src/Overload.sol";

import {ConsensusRevertAllMock} from "./mocks/ConsensusMock.sol";
import {ERC20Fee} from "./mocks/ERC20Fee.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract OverloadConsensusTest is Test {
    using TokenIdLib for uint256;
    using TokenIdLib for address;

    event Deposit(address indexed caller, address indexed owner, address indexed token, uint256 amount);
    event Withdraw(address indexed caller, address owner, address indexed token, uint256 amount, address recipient);

    Overload public overload;
    ERC20Mock public token;
    ConsensusRevertAllMock public consensusRevert;

    function setUp() public {
        overload = new Overload();
        token = new ERC20Mock("Test", "TEST", 18);
        consensusRevert = new ConsensusRevertAllMock(address(overload));
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

    /*//////////////////////////////////////////////////////////////
                            CONSENSUS REVERT
    //////////////////////////////////////////////////////////////*/

    function test_delegate() public {
        deposit(address(0xBEEF));

        DelegationKey memory key = DelegationKey({
            owner: address(0xBEEF),
            token: address(token),
            consensus: address(consensusRevert),
            validator: address(0xCCCC)
        });

        vm.prank(address(0xBEEF));
        vm.expectRevert();
        overload.delegate(key, 50, "", true);
        assertEq(overload.getDelegationsLength(address(0xBEEF), address(token)), 0);

        vm.prank(address(0xBEEF));
        overload.delegate(key, 50, "", false);
        assertEq(overload.getDelegationsLength(address(0xBEEF), address(token)), 1);
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).consensus, address(consensusRevert));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).validator, address(0xCCCC));
        assertEq(overload.getDelegation(address(0xBEEF), address(token), 0).amount, 50);
    }
}
