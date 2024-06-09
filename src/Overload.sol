// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {COverload} from "./abstracts/COverload.sol";
import {Lock} from "./abstracts/Lock.sol";
import {EOverload} from "./interfaces/EOverload.sol";
import {IOverload} from "./interfaces/IOverload.sol";
import {CastLib} from "./libraries/CastLib.sol";
import {TokenIdLib} from "./libraries/TokenIdLib.sol";
import {DelegationLib, Delegation, DelegationKey} from "./libraries/types/Delegation.sol";
import {UndelegationLib, Undelegation, UndelegationKey} from "./libraries/types/Undelegation.sol";
import {ERC6909} from "./tokens/ERC6909.sol";

/// @title Overload
/// @author @egozoq
/// @notice A minimal, modular and generalized restaking contract.
contract Overload is IOverload, EOverload, COverload, ERC6909, Lock {
    using CastLib for uint256;
    using CastLib for int256;
    using TokenIdLib for uint256;
    using TokenIdLib for address;

    using DelegationLib for mapping(address owner => mapping(address token => Delegation[]));
    using UndelegationLib for mapping(address owner => mapping(address token => Undelegation[]));

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IOverload
    uint256 public constant GAS_BUDGET = 2 ** 20; // 1_048_576
    /// @inheritdoc IOverload
    uint256 public constant MAX_DELEGATIONS = 2 ** 8; // 256
    /// @inheritdoc IOverload
    uint256 public constant MAX_UNDELEGATIONS = 2 ** 8; // 256

    /// @inheritdoc IOverload
    uint256 public constant MAX_DELAY = 604_800; // 7 days

    /// @inheritdoc IOverload
    uint256 public constant MIN_COOLDOWN = 14_400; // 4 hours
    /// @inheritdoc IOverload
    uint256 public constant MAX_COOLDOWN = 604_800; // 7 days

    /// @inheritdoc IOverload
    uint256 public constant MAX_JAILTIME = 604_800; // 7 days

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IOverload
    mapping(address consensus => uint256 delay) public delays;
    /// @inheritdoc IOverload
    mapping(address consensus => uint256 cooldown) public cooldowns;
    /// @inheritdoc IOverload
    mapping(address consensus => mapping(address validator => uint256 timestamp)) public jailed;

    /// @inheritdoc IOverload
    mapping(address owner => mapping(address token => uint256 amount)) public bonded;
    /// @inheritdoc IOverload
    mapping(address owner => mapping(address token => mapping(address consensus => bool))) public delegated;
    /// @notice The mapping for delegations arrays.
    mapping(address owner => mapping(address token => Delegation[])) public delegations;
    /// @notice The mapping for undelegations arrays.
    mapping(address owner => mapping(address token => Undelegation[])) public undelegations;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           VIEWS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Delegation
     */

    /// @inheritdoc IOverload
    function getDelegationsLength(address owner, address token) public view returns (uint256) {
        return delegations[owner][token].length;
    }

    /// @inheritdoc IOverload
    function getDelegations(address owner, address token) public view returns (Delegation[] memory) {
        return delegations[owner][token];
    }

    /// @inheritdoc IOverload
    function getDelegation(address owner, address token, uint256 index) public view returns (Delegation memory) {
        if (index < delegations[owner][token].length) {
            return delegations[owner][token][index];
        } else {
            return DelegationLib.zero();
        }
    }

    /// @inheritdoc IOverload
    function getDelegation(DelegationKey memory key) public view returns (Delegation memory delegation) {
        (delegation, ) = delegations.get(key, false);
    }

    /**
     * Undelegation
     */

    /// @inheritdoc IOverload
    function getUndelegationLength(address owner, address token) public view returns (uint256) {
        return undelegations[owner][token].length;
    }

    /// @inheritdoc IOverload
    function getUndelegations(address owner, address token) public view returns (Undelegation[] memory) {
        return undelegations[owner][token];
    }

    /// @inheritdoc IOverload
    function getUndelegation(address owner, address token, uint256 index) public view returns (Undelegation memory) {
        if (index < undelegations[owner][token].length) {
            return undelegations[owner][token][index];
        } else {
            return UndelegationLib.zero();
        }
    }

    /// @inheritdoc IOverload
    function getUndelegation(UndelegationKey memory key) public view returns (Undelegation memory undelegation) {
        (undelegation, ) = undelegations.get(key, false);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ADMIN                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IOverload
    function setDelay(address consensus, uint256 delay) public lock returns (bool) {
        require(msg.sender == consensus || isOperator[consensus][msg.sender], Unauthorized());
        require(delay <= MAX_DELAY, ValueExceedsMaxDelay());

        delays[consensus] = delay;

        emit SetDelay(consensus, delay);

        return true;
    }

    /// @inheritdoc IOverload
    function setCooldown(address consensus, uint256 cooldown) public lock returns (bool) {
        require(msg.sender == consensus || isOperator[consensus][msg.sender], Unauthorized());
        require(cooldown <= MAX_COOLDOWN, ValueExceedsMaxCooldown());
        require(cooldown >= MIN_COOLDOWN, ValueBelowMinCooldown());

        cooldowns[consensus] = cooldown;

        emit SetCooldown(consensus, cooldown);

        return true;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      DEPOSIT/WITHDRAW                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IOverload
    function deposit(address owner, address token, uint256 amount) public lock returns (bool) {
        require(amount > 0, Zero());

        uint256 balance = IERC20(token).balanceOf(address(this));
        SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);
        uint256 deposited = IERC20(token).balanceOf(address(this)) - balance;
        _mint(owner, token.convertToId(), deposited);

        emit Deposit(msg.sender, owner, token, deposited);

        return true;
    }

    /// @inheritdoc IOverload
    function withdraw(address owner, address token, uint256 amount, address recipient) public lock returns (bool) {
        if (msg.sender != owner && !isOperator[owner][msg.sender]) {
            uint256 allowed = allowance[owner][msg.sender][token.convertToId()];

            if (allowed != type(uint256).max) {
                allowance[owner][msg.sender][token.convertToId()] = allowed - amount;
            }
        }
        require(amount > 0, Zero());

        _burn(owner, token.convertToId(), amount);
        SafeERC20.safeTransfer(IERC20(token), recipient, amount);

        emit Withdraw(msg.sender, owner, token, amount, recipient);

        return true;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         RESTAKING                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IOverload
    function delegate(DelegationKey memory key, uint256 amount, bytes calldata data, bool strict) public lock returns (bool) {
        // Check for owner or approval
        if (msg.sender != key.owner && !isOperator[key.owner][msg.sender]) {
            uint256 allowed = allowance[key.owner][msg.sender][key.token.convertToId()];

            if (allowed != type(uint256).max) {
                allowance[key.owner][msg.sender][key.token.convertToId()] = allowed - amount;
            }
        }
        require(amount > 0, Zero());
        // Check below max delegations amount
        require(delegations[key.owner][key.token].length < MAX_DELEGATIONS, MaxDelegationsReached());

        // Before hook call
        _beforeDelegateHook(key.consensus, GAS_BUDGET, key, amount, data, strict);

        uint256 balance = balanceOf[key.owner][key.token.convertToId()] + bonded[key.owner][key.token];

        Delegation memory delegation;
        uint256 index;
        if (delegated[key.owner][key.token][key.consensus]) {
            int256 position;

            // Strictly get delegation
            (delegation, position) = delegations.get(key, true);
            require((delegation.amount + amount) <= balance, Overflow());

            // Increase delegation amount
            _bondTokens(key.owner, key.token, delegation.amount + amount);
            index = position.u256();
            delegation = delegations.increase(key.owner, key.token, index, amount);
        } else {
            require(amount <= balance, Overflow());

            // Create delegation
            _bondTokens(key.owner, key.token, amount);
            (delegation, index) = delegations.add(key, amount);

            // Mark that delegation exists
            delegated[key.owner][key.token][key.consensus] = true;
        }

        // After hook call
        _afterDelegateHook(key.consensus, GAS_BUDGET, key, amount, data, strict, delegation, index);

        emit Delegate(key, amount, data, strict, index);

        return true;
    }

    /// @inheritdoc IOverload
    function redelegate(
        DelegationKey memory from,
        DelegationKey memory to,
        bytes calldata data,
        bool strict
    ) public lock returns (bool) {
        require(from.owner == to.owner, MismatchAddress(from.owner, to.owner));
        require(from.token == to.token, MismatchAddress(from.token, to.token));
        require(from.consensus == to.consensus, MismatchAddress(from.consensus, to.consensus));
        require(from.validator != to.validator, Zero());
        require(msg.sender == to.owner || !isOperator[to.owner][msg.sender], Unauthorized());
    
        (, int256 index) = delegations.get(from, true);
        require(index >= 0, NotFound());

        // Before hook
        _beforeRedelegateHook(from.consensus, GAS_BUDGET, from, to, data, strict);

        delegations[from.owner][from.token][index.u256()].validator = to.validator;

        // After hook
        _afterRedelegateHook(from.consensus, GAS_BUDGET, from, to, data, strict);

        emit Redelegate(from, to, data, strict);

        return true;
    }

    /// @inheritdoc IOverload
    function undelegating(
        DelegationKey memory key,
        uint256 amount,
        bytes calldata data,
        bool strict
    ) public lock returns (bool, UndelegationKey memory undelegationKey, int256 insertIndex) {
        // Check parameters
        require(msg.sender == key.owner || isOperator[key.owner][msg.sender], Unauthorized());
        require(amount > 0, Zero());
        require(delegated[key.owner][key.token][key.consensus], NotDelegated());
        require(undelegations[key.owner][key.token].length < MAX_UNDELEGATIONS, MaxUndelegationsReached());

        // Strictly get delegation and check parameters against it
        (Delegation memory delegation, int256 index) = delegations.get(key, true);
        require(key.consensus == delegation.consensus, MismatchAddress(key.consensus, delegation.consensus));
        require(key.validator == delegation.validator, MismatchAddress(key.validator, delegation.validator));
        require(amount <= delegation.amount, Overflow());
        require(index >= 0, Fatal());

        // Check validator is not jailed
        require(jailed[key.consensus][key.validator] <= block.timestamp, Jailed());

        // Non-strict hook call
        _beforeUndelegatingHook(key.consensus, GAS_BUDGET, key, amount, data, strict, index.u256());

        // Update the delegation
        if (amount == delegation.amount) {
            delegation = delegations.remove(key.owner, key.token, index.u256());
            delegated[key.owner][key.token][key.consensus] = false;
        } else {
            delegation = delegations.decrease(key.owner, key.token, index.u256(), amount);
        }

        // Push new undelegation
        if (delays[key.consensus] > 0) {
            // Add undelegation object if there's cooldown for the consensus contract
            undelegationKey = UndelegationKey({
                owner: key.owner,
                token: key.token,
                consensus: key.consensus,
                validator: key.validator,
                amount: amount,
                maturity: block.timestamp + delays[key.consensus]
            });
            insertIndex = undelegations.add(undelegationKey).i256();
        } else {
            // If there's no cooldown, we try moving tokens to `unbonded`.
            // Tokens are moved from to `unbonded` iff it creates a new lower maxima.
            undelegationKey = UndelegationLib.zeroKey();
            insertIndex = -1;
            _bondUpdate(key.owner, key.token);
        }

        // Non-strict hook call
        _afterUndelegatingHook(key.consensus, GAS_BUDGET, key, amount, data, strict, undelegationKey, insertIndex);

        emit Undelegating(key, amount, data, strict, undelegationKey, insertIndex);

        return (true, undelegationKey, insertIndex);
    }

    /// @inheritdoc IOverload
    function undelegate(UndelegationKey memory key, int256 position, bytes calldata data, bool strict) public lock returns (bool) {
        require(msg.sender == key.owner || isOperator[key.owner][msg.sender], Unauthorized());

        Undelegation memory undelegation;
        int256 index;

        if (position >= 0) {
            undelegation = undelegations[key.owner][key.token][position.u256()];
            index = position;
        } else {
            (undelegation, index) = undelegations.get(key, true);
        }
        require(key.consensus == undelegation.consensus, MismatchAddress(key.consensus, undelegation.consensus));
        require(key.validator == undelegation.validator, MismatchAddress(key.validator, undelegation.validator));
        require(key.amount == undelegation.amount, MismatchUint256(key.amount, undelegation.amount));
        require(undelegation.maturity <= block.timestamp, NonMatureUndelegation());
        require(index >= 0, Fatal());

        // Non-strict hook call
        _beforeUndelegateHook(key.consensus, GAS_BUDGET, key, position, data, strict, index.u256());

        undelegations.remove(key, index.u256());
        _bondUpdate(key.owner, key.token);

        // Non-strict hook call
        _afterUndelegateHook(key.consensus, GAS_BUDGET, key, position, data, strict);

        emit Undelegate(key, position, data, strict);

        return true;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                            JAIL                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IOverload
    function jail(address validator, uint256 jailtime) public lock returns (bool) {
        // Cooldown prevents continuous jailing.
        uint256 cooldown = (cooldowns[msg.sender] >= MIN_COOLDOWN && cooldowns[msg.sender] <= MAX_COOLDOWN)
            ? cooldowns[msg.sender]
            : MIN_COOLDOWN;
        require(jailed[msg.sender][validator] + cooldown <= block.timestamp, JailOnCooldown());
        require(jailtime <= MAX_JAILTIME, ValueExceedsMaxJailtime());
        require(jailtime > 0, Zero());

        jailed[msg.sender][validator] = block.timestamp + jailtime;

        emit Jail(msg.sender, validator, jailtime, block.timestamp + jailtime);

        return true;
    }
    
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          INTERNAL                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Only increase the token bonding.
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
