// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Delegation, DelegationKey} from "../libraries/types/Delegation.sol";
import {Undelegation, UndelegationKey} from "../libraries/types/Undelegation.sol";

interface IHOverload {
    /*//////////////////////////////////////////////////////////////
                                DELEGATE
    //////////////////////////////////////////////////////////////*/

    function beforeDelegate(address sender, DelegationKey memory key, uint256 delta, bytes calldata data, bool strict) external returns (bytes4);

    function afterDelegate(address sender, DelegationKey memory key, uint256 delta, bytes calldata data, bool strict, Delegation memory delegation, uint256 index) external returns (bytes4);

    /*//////////////////////////////////////////////////////////////
                               REDELEGATE
    //////////////////////////////////////////////////////////////*/

    function beforeRedelegate(address sender, DelegationKey memory from, DelegationKey memory to, bytes calldata data, bool strict) external returns (bytes4);

    function afterRedelegate(address sender, DelegationKey memory from, DelegationKey memory to, bytes calldata data, bool strict) external returns (bytes4);

    /*//////////////////////////////////////////////////////////////
                              UNDELEGATING
    //////////////////////////////////////////////////////////////*/    

    function beforeUndelegating(address sender, DelegationKey memory key, uint256 delta, bytes calldata data, bool strict, uint256 delegationIndex) external returns (bytes4);

    function afterUndelegating(address sender, DelegationKey memory key, uint256 delta, bytes calldata data, bool strcit, UndelegationKey memory ukey, uint256 undelegatingIndex) external returns (bytes4);

    /*//////////////////////////////////////////////////////////////
                               UNDELEGATE
    //////////////////////////////////////////////////////////////*/

    function beforeUndelegate(address sender, UndelegationKey memory key, int256 position, bytes calldata data, bool strict, uint256 index) external returns (bytes4);

    function afterUndelegate(address sender, UndelegationKey memory key, int256 position, bytes calldata data, bool strict) external returns (bytes4);
}
