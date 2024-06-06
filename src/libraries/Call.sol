// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Call {
    function isContract(address target) internal view returns (bool) {
        return target.code.length > 0;
    }

    function functionCall(address target, bytes memory data, bool strict) internal returns (bool, bytes memory) {
        if (target.code.length == 0) {
            return (false, "");
        }

        (bool success, bytes memory result) = address(target).call(data);

        if (strict && !success) {
            _revert(result);
        } else {
            return (success, result);
        }
    }

    function functionCallGas(address target, uint256 gas, bytes memory data, bool strict) internal returns (bool, bytes memory) {
        if (target.code.length == 0) {
            return (false, "");
        }

        (bool success, bytes memory result) = address(target).call{gas: gas}(data);

        if (strict && !success) {
            _revert(result);
        } else {
            return (success, result);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              OPENZEPPELIN
    //////////////////////////////////////////////////////////////*/

    /// @dev OpenZeppelin Contracts
    /// @dev A call to an address target failed. The target may have reverted.
    error FailedCall();

    /// @dev OpenZeppelin Contracts
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
