// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {COverload} from "./abstracts/COverload.sol";
import {Lock} from "./abstracts/Lock.sol";
import {IOverload} from "./interfaces/IOverload.sol";
import {CastLib} from "./libraries/CastLib.sol";
import {TokenIdLib} from "./libraries/TokenIdLib.sol";
import {DelegationLib, Delegation, DelegationKey} from "./libraries/types/Delegation.sol";
import {UndelegationLib, Undelegation, UndelegationKey} from "./libraries/types/Undelegation.sol";
import {ERC6909} from "./tokens/ERC6909.sol";

contract Overload is IOverload, COverload, ERC6909, Lock {
    using CastLib for uint256;
    using CastLib for int256;
    using TokenIdLib for uint256;
    using TokenIdLib for address;

    using DelegationLib for mapping(address owner => mapping(address token => Delegation[]));
    using UndelegationLib for mapping(address owner => mapping(address token => Undelegation[]));

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

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Variables
    /// @notice The gas budget that a hook call has.
    /// @dev A hook not consuming withing the budget can lead to unexpected behaviours on the consensus contracts. It's
    ///     important that the implemented hooks stay within good margin of the gas budget.
    uint256 public gasBudget = 1_000_000;
    uint256 public maxDelegations = 256;
    uint256 public maxUndelegations = 32;
    uint256 public maxUndelegatingDelay = 604_800; // 7 days
    uint256 public maxJailTime = 604_800; // 7 days
    uint256 public minJailCooldown = 86_400; // 1 day

    // Canonical token accounting
    mapping(address owner => mapping(address token => uint256 amount)) public bonded;

    mapping(address owner => mapping(address token => mapping(address consensus => bool))) public delegated;
    mapping(address owner => mapping(address token => Delegation[])) public delegations;
    mapping(address owner => mapping(address token => Undelegation[])) public undelegations;

    mapping(address consensus => uint256 delay) public undelegatingDelay;
    mapping(address consensus => mapping(address validator => uint256 timestamp)) public jailed;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           VIEWS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Delegation
    function getDelegationsLength(address owner, address token) public view returns (uint256) {
        return delegations[owner][token].length;
    }

    function getDelegations(address owner, address token) public view returns (Delegation[] memory) {
        return delegations[owner][token];
    }

    function getDelegation(address owner, address token, uint256 index) public view returns (Delegation memory) {
        if (index < delegations[owner][token].length) {
            return delegations[owner][token][index];
        } else {
            return DelegationLib.zero();
        }
    }

    function getDelegation(DelegationKey memory key) public view returns (Delegation memory delegation) {
        (delegation, ) = delegations.get(key, false);
    }

    // Undelegation
    function getUndelegationLength(address owner, address token) public view returns (uint256) {
        return undelegations[owner][token].length;
    }

    function getUndelegations(address owner, address token) public view returns (Undelegation[] memory) {
        return undelegations[owner][token];
    }

    function getUndelegation(address owner, address token, uint256 index) public view returns (Undelegation memory) {
        if (index < undelegations[owner][token].length) {
            return undelegations[owner][token][index];
        } else {
            return UndelegationLib.zero();
        }
    }

    function getUndelegation(UndelegationKey memory key) public view returns (Undelegation memory undelegation) {
        (undelegation, ) = undelegations.get(key, false);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ADMIN                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function setUndelegatingDelay(address consensus, uint256 delay) public lock returns (bool) {
        require(msg.sender == consensus || isOperator[consensus][msg.sender], Unauthorized());
        require(delay <= maxUndelegatingDelay, ValueExceedsMaxDelay());

        undelegatingDelay[consensus] = delay;

        emit SetUndelegatingDelay(consensus, delay);

        return true;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      DEPOSIT/WITHDRAW                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function deposit(address owner, address token, uint256 amount) public lock returns (bool) {
        require(amount > 0, Zero());

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
        require(amount > 0, Zero());

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
        require(delta > 0, Zero());
        // Check below max delegations amount
        require(delegations[key.owner][key.token].length < maxDelegations, MaxDelegationsReached());

        // Before hook call
        _beforeDelegateHook(key.consensus, gasBudget, key, delta, data, strict);

        uint256 balance = balanceOf[key.owner][key.token.convertToId()] + bonded[key.owner][key.token];

        Delegation memory delegation;
        if (delegated[key.owner][key.token][key.consensus]) {
            int256 index;

            // Strictly get delegation
            (delegation, index) = delegations.get(key, true);
            require((delegation.amount + delta) <= balance, Overflow());

            // Increase delegation amount
            _bondTokens(key.owner, key.token, delegation.amount + delta);
            delegation = delegations.increase(key.owner, key.token, index.u256(), delta);
        } else {
            require(delta <= balance, Overflow());

            // Create delegation
            _bondTokens(key.owner, key.token, delta);
            delegation = delegations.push(key, delta);

            // Mark that delegation exists
            delegated[key.owner][key.token][key.consensus] = true;
        }

        // After hook call
        _afterDelegateHook(key.consensus, gasBudget, key, delta, data, strict, delegation);

        emit Delegate(key, delta, data, strict);

        return true;
    }

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
        _beforeRedelegateHook(from.consensus, gasBudget, from, to, data, strict);

        delegations[from.owner][from.token][index.u256()].validator = to.validator;

        // After hook
        _afterRedelegateHook(from.consensus, gasBudget, from, to, data, strict);

        emit Redelegate(from, to, data, strict);

        return true;
    }

    /// @dev Convert a specific `Delegaton` object to `Undelegation`
    function undelegating(
        DelegationKey memory key,
        uint256 delta,
        bytes calldata data,
        bool strict
    ) public lock returns (bool, UndelegationKey memory undelegationKey, uint256 insertIndex) {
        // Check parameters
        require(msg.sender == key.owner || isOperator[key.owner][msg.sender], Unauthorized());
        require(delta > 0, Zero());
        require(delegated[key.owner][key.token][key.consensus], NotDelegated());
        require(undelegations[key.owner][key.token].length < maxUndelegations, MaxUndelegationsReached());

        // Strictly get delegation and check parameters against it
        (Delegation memory delegation, int256 index) = delegations.get(key, true);
        require(key.consensus == delegation.consensus, MismatchAddress(key.consensus, delegation.consensus));
        require(key.validator == delegation.validator, MismatchAddress(key.validator, delegation.validator));
        require(delta <= delegation.amount, Overflow());
        require(index >= 0, Fatal());

        // Check validator is not jailed
        require(jailed[key.consensus][key.validator] <= block.timestamp, Jailed());

        // Non-strict hook call
        _beforeUndelegatingHook(key.consensus, gasBudget, key, delta, data, strict, index.u256());

        // Update the delegation
        if (delta == delegation.amount) {
            delegation = delegations.remove(key.owner, key.token, index.u256());
            delegated[key.owner][key.token][key.consensus] = false;
        } else {
            delegation = delegations.decrease(key.owner, key.token, index.u256(), delta);
        }

        // Push new undelegation
        if (undelegatingDelay[key.consensus] > 0) {
            // Add undelegation object if there's cooldown for the consensus contract
            undelegationKey = UndelegationKey({
                owner: key.owner,
                token: key.token,
                consensus: key.consensus,
                validator: key.validator,
                amount: delta,
                maturity: block.timestamp + undelegatingDelay[key.consensus]
            });
            insertIndex = undelegations.add(undelegationKey);
        } else {
            // If there's no cooldown, we try moving tokens to `unbonded`.
            // Tokens are moved from to `unbonded` iff it creates a new lower maxima.
            undelegationKey = UndelegationLib.zeroKey();
            _bondUpdate(key.owner, key.token);
        }

        // Non-strict hook call
        _afterUndelegatingHook(key.consensus, gasBudget, key, delta, data, strict, undelegationKey, insertIndex);

        emit Undelegating(key, delta, data, strict);

        return (true, undelegationKey, insertIndex);
    }

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
        _beforeUndelegateHook(key.consensus, gasBudget, key, position, data, strict, index.u256());

        undelegations.remove(key, index.u256());
        _bondUpdate(key.owner, key.token);

        // Non-strict hook call
        _afterUndelegateHook(key.consensus, gasBudget, key, position, data, strict);

        emit Undelegate(key, position, data, strict);

        return true;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                            JAIL                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev When `block.timestamp` is below `minJailCooldown`, then the `jail` function will stop working. We do not
    ///     expect the `block.timestamp` to be of such value although, the timestamp should always strictly be higher
    ///     than `minJailCooldown` - otherwise a blockchain has been configured wrongly, or it's a testchain.
    function jail(address validator, uint256 jailtime) public lock returns (bool) {
        // A validator cannot be continously jailed, a minimum cooldown is required.
        require(jailed[msg.sender][validator] + minJailCooldown <= block.timestamp, JailOnCooldown());
        require(jailtime <= maxJailTime, ValueExceedsMaxJailtime());

        if (jailtime > 0) {
            jailed[msg.sender][validator] = block.timestamp + jailtime;
        }

        emit Jail(msg.sender, validator, jailtime, block.timestamp + jailtime);

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
