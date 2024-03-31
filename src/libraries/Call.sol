// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Call {
    error FailedCall();

    function isContract(address target) internal view returns (bool) {
        return target.code.length > 0;
    }

    function call(address target, bytes memory data, bool strict) internal returns (bool success, bytes memory result) {
        if (target.code.length == 0) {
            return (false, "");
        }

        (success, result) = address(target).call(data);

        if (strict && !success) {
            _revert(result);
        }
    }

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
