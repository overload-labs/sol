// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library FunctionCallLib {
    /// @notice There's no code at `target` (it is not a contract).
    /// @dev OpenZeppelin Contracts @ 5.0.2
    error AddressEmptyCode(address target);
    /// @notice A call to an address target failed. The target may have reverted.
    /// @dev OpenZeppelin Contracts @ 5.0.2
    error FailedCall();
    /// @notice Reverts when insufficent gas is left from `gasleft()` for `functionCallGas`.
    error InsufficientGas(uint256 gasLeft);

    function functionCall(address target, bytes memory data, bool strict) internal returns (bool, bytes memory) {
        return functionCallGas(target, 0, data, strict);
    }

    function functionCallGas(address target, uint256 gas, bytes memory data, bool strict) internal returns (bool, bytes memory) {
        uint256 gasLeft = gasleft();
        require(gasLeft >= gas, InsufficientGas(gasLeft));

        (bool success, bytes memory result) = address(target).call{gas: gas}(data);

        if (strict) {
            if (!success) {
                _revert(result);
            } else {
                if (result.length == 0 && target.code.length == 0) {
                    revert AddressEmptyCode(target);
                } else {
                    return (success, result);
                }
            }
        } else {
            return (success, result);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              OPENZEPPELIN
    //////////////////////////////////////////////////////////////*/

    /// @notice Reverts with returndata if present. Otherwise reverts with {Errors.FailedCall}.
    /// @dev OpenZeppelin Contracts @ 5.0.2
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedCall();
        }
    }
}
