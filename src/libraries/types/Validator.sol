// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Validator {
    uint256 amount;
    bool active;

    uint32 startBlock;
    uint32 endBlock;
}

struct ValidatorKey {
    address consensus;
    address validator;
    address token;
}

library ValidatorLib {
    function zero() internal pure returns (Validator memory) {
        return Validator({
            amount: 0,
            active: false,
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

    function increase(Validator[] storage checkpoints, uint256 delta) internal {
        uint256 length = checkpoints.length;

        if (length > 0) {
            push(checkpoints, checkpoints[length - 1].amount + delta);
        } else {
            push(checkpoints, delta);
        }
    }

    function decrease(Validator[] storage checkpoints, uint256 delta) internal {
        uint256 length = checkpoints.length;

        if (length > 0) {
            push(checkpoints, checkpoints[length - 1].amount - delta);
        } else {
            revert("ValidatorLib: arithmetic underflow");
        }
    }

    function push(Validator[] storage checkpoints, uint256 amount) internal {
        uint256 length = checkpoints.length;

        if (length > 0 && checkpoints[length - 1].startBlock == block.number) {
            checkpoints[length - 1].amount = uint256(amount);
        } else {
            if (length > 0) {
                checkpoints[length - 1].endBlock = uint32(block.number) - uint32(1);
                checkpoints.push(
                    Validator({
                        amount: uint256(amount),
                        active: checkpoints[length - 1].active,
                        startBlock: uint32(block.number),
                        endBlock: uint32(0)
                    })
                );
            } else {
                checkpoints.push(
                    Validator({
                        amount: uint256(amount),
                        active: false,
                        startBlock: uint32(block.number),
                        endBlock: uint32(0)
                    })
                );
            }
        }
    }
}
