// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DelegationLib, Delegation, DelegationKey} from "../libraries/types/Delegation.sol";
import {UndelegationLib, Undelegation, UndelegationKey} from "../libraries/types/Undelegation.sol";

interface EOverload {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    event SetUndelegatingDelay(address indexed consensus, uint256 cooldown);
    event Deposit(address indexed caller, address indexed owner, address indexed token, uint256 amount);
    event Withdraw(address indexed caller, address owner, address indexed token, uint256 amount, address recipient);
    event Delegate(DelegationKey indexed key, uint256 delta, bytes data, bool strict);
    event Redelegate(DelegationKey indexed from, DelegationKey indexed to, bytes data, bool strict);
    event Undelegating(DelegationKey indexed key, uint256 delta, bytes data, bool strict);
    event Undelegate(UndelegationKey indexed key, int256 position, bytes data, bool strict);
    event Jail(address indexed consensus, address indexed validator, uint256 jailtime, uint256 timestamp);

        /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // General errors
    error Unauthorized();
    error MismatchAddress(address a, address b);
    error MismatchUint256(uint256 a, uint256 b);
    error NotFound();
    error Overflow();
    error Fatal();
    error Zero();

    // Specific errors
    error ValueExceedsMaxDelay();
    error ValueExceedsMaxJailtime();
    error MaxDelegationsReached();
    error MaxUndelegationsReached();
    error NonMatureUndelegation();
    error JailOnCooldown();
    error NotDelegated();
    error Jailed();
}
