// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import {IOverloadHooks} from "../../src/interfaces/IOverloadHooks.sol";

// import {Delegation, DelegationKey} from "../../src/libraries/types/Delegation.sol";
// import {Validator} from "../../src/libraries/types/Validator.sol";
// import {Pool} from "../../src/libraries/types/Pool.sol";

// contract ConsensusWithBeforeHook {
//     uint256 public counter = 0;

//     function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
//         return
//             interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
//             interfaceId == IOverloadHooks.beforeDelegate.selector;
//     }

//     function beforeDelegate(address, DelegationKey memory, uint256, bytes calldata) external returns (bytes4) {
//         counter += 1;
//         return IOverloadHooks.beforeDelegate.selector;
//     }

//     // Should not reach `afterDelegate`, because it's not included in supportsInterface.
//     function afterDelegate(address, DelegationKey memory, uint256, Delegation memory, Validator memory, Pool memory, bytes calldata) external pure returns (bytes4) {
//         revert();
//     }
// }

// contract ConsensusRevertHook {
//     function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
//         return
//             interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
//             interfaceId == IOverloadHooks.beforeDelegate.selector;
//     }

//     function beforeDelegate(address, DelegationKey memory, uint256, bytes calldata) external pure returns (bytes4) {
//         revert();
//     }
// }

// contract ConsensusNoHook {
//     function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
//         return
//             interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
//             interfaceId == IOverloadHooks.beforeDelegate.selector;
//     }
// }

// contract ConsensusNoSupportInterface {
//     function beforeDelegate(address, DelegationKey memory, uint256, bytes calldata) external pure returns (bytes4) {
//         return IOverloadHooks.beforeDelegate.selector;
//     }
// }

// contract ConsensusSupportInterfaceRevert {
//     function supportsInterface(bytes4) public pure returns (bool) {
//         revert();
//     }
// }
