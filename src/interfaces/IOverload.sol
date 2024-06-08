// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Delegation, DelegationKey} from "../libraries/types/Delegation.sol";
import {Undelegation, UndelegationKey} from "../libraries/types/Undelegation.sol";

/// @title IOverload (Overload Interface)
interface IOverload {
    /// @notice Returns the length of the delegations array.
    /// @param owner The owner of the delegations.
    /// @param token The token used for the delegations array.
    function getDelegationsLength(address owner, address token) external view returns (uint256);

    /// @notice Returns all the delegations for a user and a token.
    /// @param owner The owner of the delgations.
    /// @param token The token for the delegations.
    function getDelegations(address owner, address token) external view returns (Delegation[] memory);

    /// @notice Returns a delegation using an index.
    /// @param owner The owner of the delgation.
    /// @param token The token being delegated.
    /// @param index The index of the delegation in the delegations array.
    function getDelegation(address owner, address token, uint256 index) external view returns (Delegation memory);

    /// @notice Returns a delegation using a delegation key.
    /// @param key The key of the delegation in the delegations array.
    function getDelegation(DelegationKey memory key) external view returns (Delegation memory delegation);

    /// @notice Returns the length of the undelegations array.
    /// @param owner The owner of the undelegations.
    /// @param token The token used for the undelegations array.
    function getUndelegationLength(address owner, address token) external view returns (uint256);

    /// @notice Returns all the delegations for a user and a token.
    /// @param owner The owner of the undelgations.
    /// @param token The token for the undelegations.
    function getUndelegations(address owner, address token) external view returns (Undelegation[] memory);

    /// @notice Returns an undelegation using an index.
    /// @param owner The owner of the undelgation.
    /// @param token The token being undelegated.
    /// @param index The index of the undelegation in the undelegations array.
    function getUndelegation(address owner, address token, uint256 index) external view returns (Undelegation memory);

    /// @notice Returns an undelegation using an undelegation key.
    /// @param key The key of the undelegation in the undelegations array.
    function getUndelegation(UndelegationKey memory key) external view returns (Undelegation memory undelegation);

    /// @notice Sets the undelegation delay for a consensus contract.
    /// @dev If delay is larger than zero, then a user will need to wait `delay` seconds before being able to call
    ///     `undelegate` after having just called `undelegating`.
    ///     If delay is set to zero, then calling `undelegating` will instantly remove the delegation object with no
    ///     side effects.
    /// @param consensus The consensus contract.
    /// @param delay The delay to set for the consensus contract.
    /// @return Must return true.
    function setUndelegatingDelay(address consensus, uint256 delay) external returns (bool);

    /// @notice Allows the user to deposit any ERC-20 token into the contract.
    /// @dev Should support fee-on-transfer tokens, but does not support rebasing tokens.
    /// @param owner The owner of the deposit.
    /// @param token The ERC-20 token to deposit.
    /// @param amount The amount to deposit.
    /// @return Must return true.
    function deposit(address owner, address token, uint256 amount) external returns (bool);

    /// @notice Allows the user to withdraw unbonded ERC-20 tokens (ERC-6909 tokens) from contract.
    /// @param owner The owner of the ERC-6909 tokens to withdraw from.
    /// @param token The ERC-20 token to withdraw.
    /// @param amount The amount to withdraw.
    /// @param recipient The recipient of the ERC-20 tokens.
    /// @return Must return true.
    function withdraw(address owner, address token, uint256 amount, address recipient) external returns (bool);

    /// @notice Delegate/Restake tokens to a consensus contract and a validator.
    /// @dev Depending on current delegated tokens, it might or might not increase the `bonded` tokens.
    ///     The bonded amount is set to the max delegated amount.
    /// @param key The delegation key.
    /// @param delta The amount of tokens to delegate.
    /// @param data The data to send to the before and after hooks.
    /// @param strict If true, then hook reverts are bubbled up, otherwise they are ignored.
    /// @return Must return true.
    function delegate(DelegationKey memory key, uint256 delta, bytes calldata data, bool strict) external returns (bool);

    /// @notice Changes the validator from `from.validator` to `to.validator` for a consensus contract.
    /// @param from The initial delegation key.
    /// @param to The delegation key with a changed validator value.
    /// @param data The data to send to the before and after hooks.
    /// @param strict If true, then hook reverts are bubbled up, otherwise they are ignored.
    /// @return Must return true.
    function redelegate(DelegationKey memory from, DelegationKey memory to, bytes calldata data, bool strict) external returns (bool);

    /// @notice Removes a delegation object and creates an undelegation object if delay for the consensus contract is
    ///     greater than zero.
    /// @dev If the delay for the consensus contract is zero, then an undelegation object will not be created.
    /// @param key The delegation key
    /// @param delta The amount of tokens to reduce from the delegation, and amount of tokens to add to a new undelegation.
    /// @param data The data to send to the before and after hooks.
    /// @param strict If true, then hook reverts are bubbled up, otherwise they are ignored.
    /// @return success Must return true.
    /// @return ukey The undelegation key.
    /// @return index The index of the created undelegation object. `-1` if no undelegation was added.
    function undelegating(DelegationKey memory key, uint256 delta, bytes calldata data, bool strict) external returns (bool success, UndelegationKey memory ukey, int256 index);

    /// @notice Remove a matured undelegation object.
    /// @dev Removing an undelegation object could lead to reduction of bonded tokens and an increase of `balanceOf`
    ///     iff the undelegation object was the singular largest bonded value.
    /// @param key The undelegation key.
    /// @param position The position of the undelegation key.
    /// @param data The data to send to the before and after hooks.
    /// @param strict If true, then hook reverts are bubbled up, otherwise they are ignored.
    /// @return Must return true.
    function undelegate(UndelegationKey memory key, int256 position, bytes calldata data, bool strict) external returns (bool);

    /// @notice Jail a validator.
    /// @dev Can only be called by the consensus contract.
    /// @dev When `block.timestamp` is below `jailCooldown`, then the `jail` function will stop working. We do not
    ///     expect the `block.timestamp` to be of such value although, the timestamp should always strictly be higher
    ///     than `jailCooldown` - otherwise a blockchain has been configured wrongly, or it's a testchain.
    /// @param validator The validator to be jailed.
    /// @param jailtime The jail time in seconds.
    /// @return Must return true.
    function jail(address validator, uint256 jailtime) external returns (bool);
}
