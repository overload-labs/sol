// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {IERC20} from "./interfaces/IERC20.sol";
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

/// @author @uniswap/v4-core (https://github.com/Uniswap/v4-core/blob/main/src/ERC6909.sol)
/// @author @egozoq (https://github.com/egozoq)
contract Overload is Lock {
    using Cast for uint256;
    using Cast for int256;
    using DelegationLib for mapping(address owner => mapping(address token => Delegation[]));
    using PoolLib for Pool[];
    using UndelegationLib for mapping(address owner => mapping(address token => Undelegation[]));
    using ValidatorLib for Validator[];

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    event OperatorSet(address indexed owner, address indexed operator, bool approved);
    event Approval(address indexed owner, address indexed spender, address indexed token, uint256 amount);
    event Transfer(address caller, address indexed from, address indexed to, address indexed token, uint256 amount);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// ERC-6909 storage
    mapping(address owner => mapping(address spender => bool)) public isOperator;
    mapping(address owner => mapping(address spender => mapping(address token => uint256 amount))) public allowance;

    // Canonical token accounting
    mapping(address owner => mapping(address token => uint256 amount)) public unbonded;
    mapping(address owner => mapping(address token => uint256 amount)) public bonded;

    // Retokenization through delegations
    mapping(address owner => mapping(address token => mapping(address consensus => bool))) public delegated;
    mapping(address owner => mapping(address token => Delegation[])) public delegations;
    mapping(address owner => mapping(address token => Undelegation[])) public undelegations;

    // Validators' stake and pool's stake
    mapping(address consensus => uint256 cooldown) public cooldowns;
    mapping(address consensus => mapping(address validator => Metadata)) public metadata;
    mapping(address consensus => mapping(address validator => mapping(address token => Validator[]))) public validators;
    mapping(address consensus => mapping(address token => Pool[])) public pools;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    TRANSIENT STORAGE                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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
        require(cooldown <= 31_556_952, "COOLDOWN_TOO_HIGH"); // max 1 year cooldown

        cooldowns[consensus] = cooldown;

        return true;
    }

    function setMetadata(address consensus, address validator, Metadata memory data) public lock returns (bool) {
        require(msg.sender == validator, "UNAUTHORIZED");

        metadata[consensus][validator] = data;

        return true;
    }

    function register(address consensus) public {
    }

    function unregister(address consensus) public {
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       OVERLOAD LOGIC                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function deposit(address owner, address token, uint256 amount) public lock returns (bool) {
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "ERC20");
        _mint(owner, token, amount);

        return true;
    }

    function withdraw(address owner, address token, uint256 amount, address recipient) public lock returns (bool) {
        if (msg.sender != owner && !isOperator[owner][msg.sender]) {
            uint256 allowed = allowance[owner][msg.sender][token];

            if (allowed != type(uint256).max) {
                allowance[owner][msg.sender][token] = allowed - amount;
            }
        }

        _burn(owner, token, amount);
        require(IERC20(token).transfer(recipient, amount), "ERC20");

        return true;
    }

    // function delegate(DelegationKey memory key, uint256 delta, bytes calldata data) public lock returns (bool) {
    function delegate(DelegationKey memory key, uint256 delta, bytes calldata data) public lock returns (bool) {
        // Checks
        if (msg.sender != key.owner && !isOperator[key.owner][msg.sender]) {
            uint256 allowed = allowance[key.owner][msg.sender][key.token];

            if (allowed != type(uint256).max) {
                allowance[key.owner][msg.sender][key.token] = allowed - delta;
            }
        }
        uint256 balance = unbonded[key.owner][key.token] + bonded[key.owner][key.token];
        require(delta <= balance, "OVERFLOW_AMT");

        // Hook before
        _beforeDelegateHook(key.consensus, key, delta, data);

        // Update delegation
        Delegation memory delegation;
        if (delegated[key.owner][key.token][key.consensus]) {
            /**
             * If delegation already exists for `consensus`, then find delegation and then increase
             */

            int256 index;
            (delegation, index) = delegations.get(key, true);
            uint256 amount = delegation.amount + delta;
            require(amount <= balance, "OVERFLOW_SUM");

            _bondIncrease(key.owner, key.token, amount);
            delegation = delegations.increase(key.owner, key.token, index.u256(), delta);
        } else {
            /**
             * If no existing delegation exists, push a new delegation into array
             */

            _bondIncrease(key.owner, key.token, delta);
            delegated[key.owner][key.token][key.consensus] = true;
            delegation = delegations.push(key, delta);
        }

        // Update validator and pool
        Validator memory validator = validators[key.consensus][key.validator][key.token].increase(delta);
        Pool memory pool = pools[key.consensus][key.token].increase(validator.active, delta);

        // Hook after
        _afterDelegateHook(key.consensus, key, delta, delegation, validator, pool, data);

        return true;
    }

    /// @dev Convert a specific `Delegaton` object to `Undelegation`
    function undelegating(
        DelegationKey memory key,
        uint256 delta
    ) public lock returns (bool success, UndelegationKey memory keyRet) {
        require(msg.sender == key.owner || isOperator[key.owner][msg.sender]);
        require(delta > 0);
        require(delegated[key.owner][key.token][key.consensus], "NO_DELEGATION");
        require(undelegations[key.owner][key.token].length <= 32, "MAX_LENGTH");

        // Get the delegation and index
        (Delegation memory delegation, int256 index) = delegations.get(key, true);
        require(key.consensus == delegation.consensus, "MISMATCH_CONSENSUS");
        require(key.validator == delegation.validator, "MISMATCH_VALIDATOR");
        require(delta <= delegation.amount, "OVERFLOW");
        require(index >= 0, "FATAL");

        // Update the delegation object before bonding update.
        if (delta == delegation.amount) {
            delegations.remove(key.owner, key.token, index.u256());
            delegated[key.owner][key.token][key.consensus] = false;
        } else {
            delegations.decrease(key.owner, key.token, index.u256(), delta);
        }

        // Update undeledations/bond update
        if (cooldowns[key.consensus] > 0) {
            // Add undelegation object if there's cooldown for the consensus contract
            success = true;
            keyRet = UndelegationKey({
                owner: key.owner,
                token: key.token,
                consensus: key.consensus,
                validator: key.validator,
                amount: delta,
                completion: block.timestamp + cooldowns[key.consensus]
            });
            undelegations.add(keyRet);
        } else {
            // If there's no cooldown, we can instantly move tokens to `unbonded`, iff it reduces the maxima value.
            success = true;
            keyRet = UndelegationLib.zeroKey();
            _bond(key.owner, key.token);
        }

        // Update validator and pool
        validators[key.consensus][key.validator][key.token].decrease(delta);
        pools[key.consensus][key.token].decrease(
            validators[key.consensus][key.validator][key.token].head().active,
            delta
        );

        return (success, keyRet);
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

    function cancel(UndelegationKey memory key) public lock returns (bool) {
        require(msg.sender == key.owner || isOperator[key.owner][msg.sender]);

        return true;
    }

    function flush(address owner, address token) public lock returns (uint256 success, uint256 failed) {
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
    /*                       ERC-6909 LOGIC                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function transfer(address to, address token, uint256 amount) public lock returns (bool) {
        unbonded[msg.sender][token] -= amount;
        unbonded[to][token] += amount;

        emit Transfer(msg.sender, msg.sender, to, token, amount);

        return true;
    }

    function transferFrom(address from, address to, address token, uint256 amount) public lock returns (bool) {
        if (!isOperator[from][msg.sender]) {
            uint256 allowed = allowance[from][msg.sender][token];

            if (allowed != type(uint256).max) {
                allowance[from][msg.sender][token] = allowed - amount;
            }
        }

        unbonded[from][token] -= amount;
        unbonded[to][token] += amount;

        emit Transfer(msg.sender, from, to, token, amount);

        return true;
    }

    function approve(address spender, address token, uint256 amount) public lock returns (bool) {
        allowance[msg.sender][spender][token] = amount;

        emit Approval(msg.sender, spender, token, amount);

        return true;
    }

    function setOperator(address operator, bool approved) public lock returns (bool) {
        isOperator[msg.sender][operator] = approved;

        emit OperatorSet(msg.sender, operator, approved);

        return true;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ERC-165 LOGIC                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x0f632fb3; // ERC165 Interface ID for ERC6909
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         HOOK CALLS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _beforeDelegateHook(
        address target,
        DelegationKey memory key,
        uint256 delta,
        bytes calldata data
    ) internal {
        if (Call.isContract(target) && ERC165Checker.supportsInterface(target, IOverloadHooks.beforeDelegate.selector)) {
            Hooks.callHook(target, abi.encodeWithSelector(IOverloadHooks.beforeDelegate.selector, msg.sender, key, delta, data), false);
        }
    }

    function _afterDelegateHook(
        address target,
        DelegationKey memory key,
        uint256 delta,
        Delegation memory delegation,
        Validator memory validator,
        Pool memory pool,
        bytes calldata data
    ) internal {
        if (Call.isContract(target) && ERC165Checker.supportsInterface(target, IOverloadHooks.afterDelegate.selector)) {
            Hooks.callHook(target, abi.encodeWithSelector(IOverloadHooks.afterDelegate.selector, msg.sender, key, delta, data), false);
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   INTERNAL BALANCE LOGIC                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // function _tokenToId(address token) internal returns (uint256) {
    //     return uint256(uint160(token));
    // }

    function _bondIncrease(address owner, address token, uint256 amount) internal {
        if (amount > bonded[owner][token]) {
            uint256 delta = amount - bonded[owner][token];

            unbonded[owner][token] -= delta;
            bonded[owner][token] += delta;
        }
    }

    /// @dev The bonding update function assumes that the `delegations` array is up-to-date.
    ///     Only call after the you have done all effects needed on the `delegations` array.
    function _bond(address owner, address token) internal {
        uint256 max = delegations.max(owner, token);
        int256 delta = max.i256() - bonded[owner][token].i256();

        if (delta > 0) {
            unbonded[owner][token] -= delta.u256();
            bonded[owner][token] += delta.u256();
        } else if (delta < 0) {
            unbonded[owner][token] += (-delta).u256();
            bonded[owner][token] -= (-delta).u256();
        } else {
            return;
        }
    }

    function _mint(address to, address token, uint256 amount) internal {
        unbonded[to][token] += amount;

        emit Transfer(msg.sender, address(0), to, token, amount);
    }

    function _burn(address from, address token, uint256 amount) internal {
        unbonded[from][token] -= amount;

        emit Transfer(msg.sender, from, address(0), token, amount);
    }
}
// 
