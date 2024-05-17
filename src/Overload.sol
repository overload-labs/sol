// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IOverloadHooks} from "./interfaces/IOverloadHooks.sol";

import {Call} from "./libraries/Call.sol";
import {Cast} from "./libraries/Cast.sol";
import {Delegation, DelegationKey, DelegationLib} from "./libraries/types/Delegation.sol";
import {Hooks} from "./libraries/Hooks.sol";
import {Lock} from "./libraries/Lock.sol";
import {Metadata} from "./libraries/types/Metadata.sol";
import {Pool, PoolLib} from "./libraries/types/Pool.sol";
import {Undelegation, UndelegationKey, UndelegationLib} from "./libraries/types/Undelegation.sol";
import {Validator, ValidatorLib} from "./libraries/types/Validator.sol";

import {TokenId} from "./libraries/TokenId.sol";
import {ERC6909} from "./tokens/ERC6909.sol";

/// @author @uniswap/v4-core (https://github.com/Uniswap/v4-core/blob/main/src/ERC6909.sol)
/// @author @egozoq (https://github.com/egozoq)
contract Overload is ERC6909, Lock {
    using Cast for uint256;
    using Cast for int256;
    using DelegationLib for mapping(address owner => mapping(address token => Delegation[]));
    using PoolLib for Pool[];
    using TokenId for uint256;
    using TokenId for address;
    using UndelegationLib for mapping(address owner => mapping(address token => Undelegation[]));
    using ValidatorLib for Validator[];

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/



    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Canonical token accounting
    mapping(address owner => mapping(address token => uint256 amount)) public bonded;

    // Retokenization through delegations
    mapping(address owner => mapping(address token => mapping(address consensus => bool))) public delegated;
    mapping(address owner => mapping(address token => Delegation[])) public delegations;
    mapping(address owner => mapping(address token => Undelegation[])) public undelegations;

    // Validators' stake and pool's stake
    uint256 public maxCoolDown = 2_629_746; // 1 month
    uint256 public maxJailTime = 7_889_238; // 3 month
    mapping(address consensus => uint256 cooldown) public cooldowns;
    mapping(address consensus => mapping(address validator => Metadata)) public metadata;
    mapping(address consensus => mapping(address validator => mapping(address token => Validator[]))) public validators;
    mapping(address consensus => mapping(address token => Pool[])) public pools;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       OVERLOAD VIEWS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function getDelegationCardinality(address owner, address token) public view returns (uint256) {
        return delegations[owner][token].length;
    }

    function getDelegationPosition(DelegationKey memory key) public view returns (int256) {
        return delegations.position(key);
    }

    function getDelegation(DelegationKey memory key) public view returns (Delegation memory delegation) {
        (delegation,) = delegations.get(key, false);
    }

    function getUndelegationCardinality(address owner, address token) public view returns (uint256) {
        return undelegations[owner][token].length;
    }

    function getUndelegationPosition(UndelegationKey memory key) public view returns (int256) {
        return undelegations.position(key);
    }

    function getUndelegation(UndelegationKey memory key) public view returns (Undelegation memory undelegation) {
        (undelegation,) = undelegations.get(key, false);
    }

    function getValidator(address consensus, address validator, address token) public view returns (Validator memory) {
        return validators[consensus][validator][token].head();
    }

    function getPool(address consensus, address token) public view returns (Pool memory) {
        return pools[consensus][token].head();
    }

    function getCooldown(address consensus) public view returns (uint256) {
        return cooldowns[consensus];
    }

    function getMetadata(address consensus, address validator) public view returns (Metadata memory) {
        return metadata[consensus][validator];
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       OVERLOAD ADMIN                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function setCooldown(address consensus, uint256 cooldown) public lock returns (bool) {
        require(msg.sender == consensus || isOperator[consensus][msg.sender], "UNAUTHORIZED");
        require(cooldown <= maxCoolDown, "COOLDOWN_TOO_HIGH");

        cooldowns[consensus] = cooldown;

        return true;
    }

    function setMetadata(address consensus, address validator, Metadata memory data) public lock returns (bool) {
        require(msg.sender == validator, "UNAUTHORIZED");

        metadata[consensus][validator] = data;

        return true;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERC-20                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function deposit(address owner, address token, uint256 amount) public lock returns (bool) {
        SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);
        _mint(owner, token.convertToId(), amount);

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

        // Check for delegation to not overflow
        uint256 balance = balanceOf[key.owner][key.token.convertToId()] + bonded[key.owner][key.token];
        require(delta <= balance, "OVERFLOW_AMT");

        // Hook before
        _beforeDelegateHook(key.consensus, key, delta, data, strict);

        // Manage delegation
        Delegation memory delegation;
        if (delegated[key.owner][key.token][key.consensus]) {
            // If delegation already exists for `consensus`, then find delegation and then increase
            int256 index;
            (delegation, index) = delegations.get(key, true);
            uint256 amount = delegation.amount + delta;
            require(amount <= balance, "OVERFLOW_SUM");

            _bondIncrease(key.owner, key.token, amount);
            delegation = delegations.increase(key.owner, key.token, index.u256(), delta);
        } else {
            // If no existing delegation exists, push a new delegation into the array
            _bondIncrease(key.owner, key.token, delta);
            delegated[key.owner][key.token][key.consensus] = true;
            delegation = delegations.push(key, delta);
        }

        // Update validator and pool
        Validator memory validator = validators[key.consensus][key.validator][key.token].increase(delta);
        Pool memory pool = pools[key.consensus][key.token].increase(delta);

        // Hook after
        _afterDelegateHook(key.consensus, key, delta, delegation, validator, pool, data, strict);

        return true;
    }

    /// @dev Convert a specific `Delegaton` object to `Undelegation`
    function undelegating(
        DelegationKey memory key,
        uint256 delta,
        bytes calldata data
    ) public lock returns (bool success, UndelegationKey memory keyret) {
        // Checks
        require(msg.sender == key.owner || isOperator[key.owner][msg.sender]);
        require(delta > 0);
        require(delegated[key.owner][key.token][key.consensus], "NO_DELEGATION");
        require(undelegations[key.owner][key.token].length <= 32, "MAX_LENGTH");
        (Delegation memory delegation, int256 index) = delegations.get(key, true);
        require(key.consensus == delegation.consensus, "MISMATCH_CONSENSUS");
        require(key.validator == delegation.validator, "MISMATCH_VALIDATOR");
        require(delta <= delegation.amount, "OVERFLOW");
        require(index >= 0, "FATAL");

        // Hook before
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
            success = true;
            keyret = UndelegationKey({
                owner: key.owner,
                token: key.token,
                consensus: key.consensus,
                validator: key.validator,
                amount: delta,
                completion: block.timestamp + cooldowns[key.consensus]
            });
            undelegations.add(keyret);
        } else {
            // If there's no cooldown, we try moving tokens to `unbonded`.
            // Tokens are moved from to `unbonded` iff it creates a new lower maxima.
            success = true;
            keyret = UndelegationLib.zeroKey();
            _bond(key.owner, key.token);
        }

        // Update validator and pool
        Validator memory validator = validators[key.consensus][key.validator][key.token].decrease(delta);
        Pool memory pool = pools[key.consensus][key.token].decrease(delta);

        // Hook after
        _afterUndelegatingHook(key.consensus, key, delta, delegation, validator, pool, data);

        return (success, keyret);
    }

    function undelegatingCancel(UndelegationKey memory key) public lock returns (bool) {
        require(msg.sender == key.owner || isOperator[key.owner][msg.sender]);

        (Undelegation memory undelegation, int256 index) = undelegations.get(key, true);
        require(key.consensus == undelegation.consensus);
        require(key.validator == undelegation.validator);
        require(key.amount == undelegation.amount);
        require(index >= 0, "FATAL");

        // Manage delegation
        DelegationKey memory delegationKey = DelegationKey({
            owner: key.owner,
            token: key.token,
            consensus: key.consensus,
            validator: key.validator
        });
        Delegation memory delegation;
        if (delegated[key.owner][key.token][key.consensus]) {
            // If delegation already exists for `consensus`, then find delegation and then increase
            (delegation, index) = delegations.get(delegationKey, true);
            delegation = delegations.increase(key.owner, key.token, index.u256(), undelegation.amount);
        } else {
            // If no existing delegation exists, push a new delegation into the array
            delegated[key.owner][key.token][key.consensus] = true;
            delegation = delegations.push(delegationKey, undelegation.amount);
        }

        // Update validator and pool
        Validator memory validator = validators[key.consensus][key.validator][key.token].increase(undelegation.amount);
        Pool memory pool = pools[key.consensus][key.token].increase(undelegation.amount);

        return true;
    }

    function undelegate(UndelegationKey memory key) public lock returns (bool) {
        require(msg.sender == key.owner || isOperator[key.owner][msg.sender]);

        (Undelegation memory undelegation, int256 index) = undelegations.get(key, true);
        require(key.consensus == undelegation.consensus);
        require(key.validator == undelegation.validator);
        require(key.amount == undelegation.amount);
        require(undelegation.completion <= block.timestamp, "NOT_COMPLETE");
        require(index >= 0, "FATAL");

        undelegations.remove(key, index.u256());
        _bond(key.owner, key.token);

        return true;
    }

    function undelegateAll(address owner, address token) public lock returns (uint256 success, uint256 failed) {
        require(msg.sender == owner || isOperator[owner][msg.sender]);

        // Start iterating from the last element towards the first
        for (uint256 i = undelegations[owner][token].length; i > 0; i--) {
            uint256 index = i - 1; // Adjust index because arrays are 0-indexed

            if (undelegations[owner][token][index].completion <= block.timestamp) {
                Undelegation memory undelegation = undelegations[owner][token][index];
                UndelegationKey memory key = UndelegationKey({
                    owner: owner,
                    token: token,
                    consensus: undelegation.consensus,
                    validator: undelegation.validator,
                    amount: undelegation.amount,
                    completion: undelegation.completion
                });

                undelegations.remove(key, index);
                success += 1;
            } else {
                failed += 1;
            }
        }

        _bond(owner, token);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                            JAIL                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/



    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         HOOK CALLS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _beforeDelegateHook(
        address target,
        DelegationKey memory key,
        uint256 delta,
        bytes calldata data,
        bool strict
    ) internal {
        if (Call.isContract(target) && ERC165Checker.supportsInterface(target, IOverloadHooks.beforeDelegate.selector)) {
            Hooks.callHook(target, abi.encodeWithSelector(IOverloadHooks.beforeDelegate.selector, msg.sender, key, delta, data), strict);
        }
    }

    function _afterDelegateHook(
        address target,
        DelegationKey memory key,
        uint256 delta,
        Delegation memory delegation,
        Validator memory validator,
        Pool memory pool,
        bytes calldata data,
        bool strict
    ) internal {
        if (Call.isContract(target) && ERC165Checker.supportsInterface(target, IOverloadHooks.afterDelegate.selector)) {
            Hooks.callHook(
                target,
                abi.encodeWithSelector(
                    IOverloadHooks.afterDelegate.selector,
                    msg.sender,
                    key,
                    delta,
                    delegation,
                    validator,
                    pool,
                    data
                ),
                strict
            );
        }
    }

    function _beforeUndelegatingHook(
        address target,
        DelegationKey memory key,
        uint256 delta,
        bytes calldata data
    ) internal {
        if (Call.isContract(target) && ERC165Checker.supportsInterface(target, IOverloadHooks.beforeDelegate.selector)) {
            Hooks.callHook(target, abi.encodeWithSelector(IOverloadHooks.beforeUndelegating.selector, msg.sender, key, delta, data), false);
        }
    }

    function _afterUndelegatingHook(
        address target,
        DelegationKey memory key,
        uint256 delta,
        Delegation memory delegation,
        Validator memory validator,
        Pool memory pool,
        bytes calldata data
    ) internal {
        if (Call.isContract(target) && ERC165Checker.supportsInterface(target, IOverloadHooks.afterUndelegating.selector)) {
            Hooks.callHook(
                target,
                abi.encodeWithSelector(
                    IOverloadHooks.afterUndelegating.selector,
                    msg.sender,
                    key,
                    delta,
                    delegation,
                    validator,
                    pool,
                    data
                ),
                false
            );
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   INTERNAL BALANCE LOGIC                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _bondIncrease(address owner, address token, uint256 amount) internal {
        if (amount > bonded[owner][token]) {
            uint256 delta = amount - bonded[owner][token];

            balanceOf[owner][token.convertToId()] -= delta;
            bonded[owner][token] += delta;
        }
    }

    /// @dev The bonding update function assumes that the `delegations` array is up-to-date.
    ///     Only call after the you have done all effects needed on the `delegations` array.
    function _bond(address owner, address token) internal {
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
