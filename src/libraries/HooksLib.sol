// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IHOverload} from "../interfaces/IHOverload.sol";
import {CallLib} from "./CallLib.sol";

library HooksLib {
    /// @notice Throws when a hook does not return its selector.
    error InvalidHookResponse();

    function callHook(address target, bytes memory data, bool strict) internal returns (bool success) {
        bytes4 expectedSelector;
        assembly { expectedSelector := mload(add(data, 0x20)) }

        // Verify that the selector was returned from the function call
        (bool success_, bytes memory result) = CallLib.functionCallGas(target, 1_000_000, data, strict);
        if (success_) {
            bytes4 selector = abi.decode(result, (bytes4));

            if (strict && selector != expectedSelector) {
                revert InvalidHookResponse();
            }
        }

        return success_;
    }
}
