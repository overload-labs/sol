// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Validator {
    uint256 amount;

    uint32 startBlock;
    uint32 endBlock;
}

struct ValidatorKey {
    address consensus;
    address validator;
    address token;
}

library ValidatorLib {
    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    function zero() internal pure returns (Validator memory) {
        return Validator({
            amount: 0,
            startBlock: 0,
            endBlock: 0
        });
    }

    function head(Validator[] storage checkpoints) internal view returns (Validator memory) {
        if (checkpoints.length > 0) {
            return checkpoints[checkpoints.length - 1];
        } else {
            return zero();
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 MUTATE
    //////////////////////////////////////////////////////////////*/

    function increase(Validator[] storage checkpoints, uint256 delta) internal returns (Validator memory validator) {
        uint256 length = checkpoints.length;

        if (length > 0) {
            validator = push(checkpoints, checkpoints[length - 1].amount + delta);
        } else {
            validator = push(checkpoints, delta);
        }
    }

    function decrease(Validator[] storage checkpoints, uint256 delta) internal returns (Validator memory validator) {
        uint256 length = checkpoints.length;

        if (length > 0) {
            validator = push(checkpoints, checkpoints[length - 1].amount - delta);
        } else {
            revert("ValidatorLib: arithmetic underflow");
        }
    }

    function push(Validator[] storage checkpoints, uint256 amount) internal returns (Validator memory validator) {
        uint256 length = checkpoints.length;

        if (length > 0 && checkpoints[length - 1].startBlock == block.number) {
            checkpoints[length - 1].amount = uint256(amount);
            validator = head(checkpoints);
        } else {
            if (length > 0) {
                checkpoints[length - 1].endBlock = uint32(block.number) - uint32(1);
                checkpoints.push(validator = Validator({
                    amount: uint256(amount),
                    startBlock: uint32(block.number),
                    endBlock: uint32(0)
                }));
            } else {
                checkpoints.push(validator = Validator({
                    amount: uint256(amount),
                    startBlock: uint32(block.number),
                    endBlock: uint32(0)
                }));
            }
        }
    }
}
