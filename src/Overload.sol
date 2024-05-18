// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {OverloadHooks} from "./abstracts/OverloadHooks.sol";
import {IOverloadHooks} from "./interfaces/IOverloadHooks.sol";
import {Cast} from "./libraries/Cast.sol";
import {Hooks} from "./libraries/Hooks.sol";
import {Lock} from "./libraries/Lock.sol";
import {TokenId} from "./libraries/TokenId.sol";
import {ERC6909} from "./tokens/ERC6909.sol";
import {DelegationLib, Delegation, DelegationKey} from "./libraries/types/Delegation.sol";
import {UndelegationLib, Undelegation, UndelegationKey} from "./libraries/types/Undelegation.sol";

contract Overload is OverloadHooks, ERC6909, Lock {
    using Cast for uint256;
    using Cast for int256;
    using TokenId for uint256;
    using TokenId for address;

    using DelegationLib for mapping(address owner => mapping(address token => Delegation[]));
    using UndelegationLib for mapping(address owner => mapping(address token => Undelegation[]));

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    event SetCooldown(address indexed consensus, uint256 cooldown);
    event SetJailtime(address indexed consensus, uint256 jailtime);

    event Deposit(address indexed caller, address indexed owner, address indexed token, uint256 amount);
    event Withdraw(address indexed caller, address owner, address indexed token, uint256 amount, address recipient);
    event Delegate(DelegationKey indexed key, uint256 delta, bytes data, bool strict);
    event Redelegate(DelegationKey indexed from, DelegationKey indexed to, bytes data);
    event Undelegating(DelegationKey indexed key, uint256 delta, bytes data);
    event Undelegate(UndelegationKey indexed key, int256 position, bytes data);
    event Jail(address indexed consensus, address indexed validator, uint256 timestamp);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Canonical token accounting
    mapping(address owner => mapping(address token => uint256 amount)) public bonded;

    uint256 public maxDelegations = 128;
    mapping(address owner => mapping(address token => mapping(address consensus => bool))) public delegated;
    mapping(address owner => mapping(address token => Delegation[])) public delegations;
    mapping(address owner => mapping(address token => Undelegation[])) public undelegations;

    uint256 public maxCoolDown = 2_629_746; // 1 month
    uint256 public maxJailTime = 2_629_746; // 1 month
    mapping(address consensus => uint256 cooldown) public cooldowns;
    mapping(address consensus => uint256 jailtime) public jailtimes;
    mapping(address consensus => mapping(address validator => uint256 timestamp)) public jailed;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ADMIN                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function setCooldown(address consensus, uint256 cooldown) public lock returns (bool) {
        require(msg.sender == consensus || isOperator[consensus][msg.sender], "UNAUTHORIZED");
        require(cooldown <= maxCoolDown, "COOLDOWN_TOO_HIGH");

        cooldowns[consensus] = cooldown;

        emit SetCooldown(consensus, cooldown);

        return true;
    }

    function setJailtime(address consensus, uint256 jailtime) public lock returns (bool) {
        require(msg.sender == consensus || isOperator[consensus][msg.sender], "UNAUTHORIZED");
        require(jailtime <= maxJailTime, "JAILTIME_TOO_HIGH");

        jailtimes[consensus] = jailtime;

        emit SetJailtime(consensus, jailtime);

        return true;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      DEPOSIT/WITHDRAW                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function deposit(address owner, address token, uint256 amount) public lock returns (bool) {
        uint256 balance = IERC20(token).balanceOf(address(this));
        SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);
        uint256 deposited = IERC20(token).balanceOf(address(this)) - balance;

        _mint(owner, token.convertToId(), deposited);

        emit Deposit(msg.sender, owner, token, deposited);

        return true;
    }

    function withdraw(address owner, address token, uint256 amount, address recipient) public lock returns (bool) {
        if (msg.sender != owner && !isOperator[owner][msg.sender]) {
            uint256 allowed = allowance[owner][msg.sender][token.convertToId()];

            if (allowed != type(uint256).max) {
                allowance[owner][msg.sender][token.convertToId()] = allowed - amount;
            }
        }

        _burn(owner, token.convertToId(), amount);
        SafeERC20.safeTransfer(IERC20(token), recipient, amount);

        emit Withdraw(msg.sender, owner, token, amount, recipient);

        return true;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         RESTAKING                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function delegate(DelegationKey memory key, uint256 delta, bytes calldata data, bool strict) public lock returns (bool) {
        // Check for owner or approval
        if (msg.sender != key.owner && !isOperator[key.owner][msg.sender]) {
            uint256 allowed = allowance[key.owner][msg.sender][key.token.convertToId()];

            if (allowed != type(uint256).max) {
                allowance[key.owner][msg.sender][key.token.convertToId()] = allowed - delta;
            }
        }

        require(delegations[key.owner][key.token].length <= maxDelegations, "MAX_DELEGATIONS");

        _beforeDelegateHook(key.consensus, key, delta, data, strict);

        uint256 balance = balanceOf[key.owner][key.token.convertToId()] + bonded[key.owner][key.token];

        Delegation memory delegation;
        if (delegated[key.owner][key.token][key.consensus]) {
            int256 index;

            // Get delegation
            (delegation, index) = delegations.get(key, true);
            require((delegation.amount + delta) <= balance, "OVERFLOW_SUM");

            // Increase delegation amount
            _bondTokens(key.owner, key.token, delegation.amount + delta);
            delegation = delegations.increase(key.owner, key.token, index.u256(), delta);
        } else {
            require(delta <= balance, "OVERFLOW_NEW");

            // Create delegation
            _bondTokens(key.owner, key.token, delta);
            delegation = delegations.push(key, delta);

            // Mark that delegation exists
            delegated[key.owner][key.token][key.consensus] = true;
        }

        _afterDelegateHook(key.consensus, key, delta, delegation, data, strict);

        emit Delegate(key, delta, data, strict);

        return true;
    }

    function redelegate(DelegationKey memory from, DelegationKey memory to, bytes calldata data) public lock returns (bool) {
        require(from.owner == to.owner, "MISMATCH_OWNER");
        require(from.token == to.token, "MISMATCH_TOKEN");
        require(from.consensus == to.consensus, "MISMATCH_CONSENSUS");
        require(msg.sender == to.owner || !isOperator[to.owner][msg.sender], "NOT_ALLOWED");
    
        (, int256 index) = delegations.get(from, true);
        require(index >= 0, "NOT_FOUND");

        _beforeRedelegateHook(from.consensus, from, to, data, true);

        delegations[from.owner][from.token][index.u256()].validator = to.validator;

        _afterRedelegateHook(from.consensus, from, to, data, true);

        emit Redelegate(from, to, data);

        return true;
    }

    /// @dev Convert a specific `Delegaton` object to `Undelegation`
    function undelegating(
        DelegationKey memory key,
        uint256 delta,
        bytes calldata data
    ) public lock returns (bool, UndelegationKey memory undelegationKey) {
        // Check parameters
        require(msg.sender == key.owner || isOperator[key.owner][msg.sender]);
        require(delta > 0);
        require(delegated[key.owner][key.token][key.consensus], "NO_DELEGATION");
        require(undelegations[key.owner][key.token].length <= 32, "MAX_LENGTH");

        // Check parameters against the read delegation object
        (Delegation memory delegation, int256 index) = delegations.get(key, true);
        require(key.consensus == delegation.consensus, "MISMATCH_CONSENSUS");
        require(key.validator == delegation.validator, "MISMATCH_VALIDATOR");
        require(delta <= delegation.amount, "OVERFLOW");
        require(index >= 0, "FATAL");

        // Check validator is not jailed
        require(jailed[key.consensus][key.validator] <= block.timestamp, "JAILED");

        // Non-strict hook call
        _beforeUndelegatingHook(key.consensus, key, delta, data);

        // Update the delegation
        if (delta == delegation.amount) {
            delegation = delegations.remove(key.owner, key.token, index.u256());
            delegated[key.owner][key.token][key.consensus] = false;
        } else {
            delegation = delegations.decrease(key.owner, key.token, index.u256(), delta);
        }

        // Push new undelegation
        if (cooldowns[key.consensus] > 0) {
            // Add undelegation object if there's cooldown for the consensus contract
            undelegationKey = UndelegationKey({
                owner: key.owner,
                token: key.token,
                consensus: key.consensus,
                validator: key.validator,
                amount: delta,
                completion: block.timestamp + cooldowns[key.consensus]
            });
            undelegations.add(undelegationKey);
        } else {
            // If there's no cooldown, we try moving tokens to `unbonded`.
            // Tokens are moved from to `unbonded` iff it creates a new lower maxima.
            undelegationKey = UndelegationLib.zeroKey();
            _bondUpdate(key.owner, key.token);
        }

        // Non-strict hook call
        _afterUndelegatingHook(key.consensus, key, delta, delegation, data);

        emit Undelegating(key, delta, data);

        return (true, undelegationKey);
    }

    function undelegate(UndelegationKey memory key, int256 position, bytes calldata data) public lock returns (bool) {
        require(msg.sender == key.owner || isOperator[key.owner][msg.sender]);

        Undelegation memory undelegation;
        int256 index;

        if (position >= 0) {
            undelegation = undelegations[key.owner][key.token][position.u256()];
            index = position;
        } else {
            (undelegation, index) = undelegations.get(key, true);
        }

        require(key.consensus == undelegation.consensus);
        require(key.validator == undelegation.validator);
        require(key.amount == undelegation.amount);
        require(undelegation.completion <= block.timestamp, "NOT_COMPLETE");
        require(index >= 0, "FATAL");

        // Non-strict hook call
        _beforeUndelegateHook(key.consensus, key, data);

        undelegations.remove(key, index.u256());
        _bondUpdate(key.owner, key.token);

        // Non-strict hook call
        _afterUndelegateHook(key.consensus, key, data);

        emit Undelegate(key, position, data);

        return true;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                            JAIL                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function jail(address validator) public lock returns (bool) {
        jailed[msg.sender][validator] = block.timestamp + jailtimes[msg.sender];

        emit Jail(msg.sender, validator, block.timestamp + jailtimes[msg.sender]);

        return true;
    }
    
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          INTERNAL                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _bondTokens(address owner, address token, uint256 amount) internal {
        if (amount > bonded[owner][token]) {
            uint256 delta = amount - bonded[owner][token];

            balanceOf[owner][token.convertToId()] -= delta;
            bonded[owner][token] += delta;
        }
    }

    /// @dev The bonding update function assumes that the `delegations` array is up-to-date.
    ///     Only call after the you have done all effects needed on the `delegations` array.
    function _bondUpdate(address owner, address token) internal {
        uint256 max = delegations.max(owner, token);
        int256 delta = max.i256() - bonded[owner][token].i256();

        if (delta > 0) {
            balanceOf[owner][token.convertToId()] -= delta.u256();
            bonded[owner][token] += delta.u256();
        } else if (delta < 0) {
            balanceOf[owner][token.convertToId()] += (-delta).u256();
            bonded[owner][token] -= (-delta).u256();
        } else {
            return;
        }
    }
}
