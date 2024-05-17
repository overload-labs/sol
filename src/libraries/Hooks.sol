// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOverloadHooks} from "../interfaces/IOverloadHooks.sol";
import {Call} from "./Call.sol";

library Hooks {
    /// @notice Throws when a hook does not return its selector.
    error InvalidHookResponse();

    function getHookmap(address target) internal returns (uint256) {
        (bool success, bytes memory result) = Call.functionCall(target, abi.encodeWithSelector(IOverloadHooks.permissions.selector), false);

        if (success) {
            return abi.decode(result, (uint256));
        } else {
            return uint256(0);
        }
    }

    function hasHook(uint256 bitmap, uint256 flag) internal pure returns (bool) {
        return uint256(bitmap) & flag != 0;
    }

    function callHook(address target, bytes memory data, bool strict) internal returns (bool success) {
        bytes4 expectedSelector;
        assembly { expectedSelector := mload(add(data, 0x20)) }

        // Verify that the selector was returned from the function call
        (bool success_, bytes memory result) = Call.functionCall(target, data, strict);
        if (success_) {
            bytes4 selector = abi.decode(result, (bytes4));

            if (strict && selector != expectedSelector) {
                revert InvalidHookResponse();
            }
        }

        return success_;
    }
}
