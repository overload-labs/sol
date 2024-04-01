// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Pool {
    uint256 amount;

    uint32 startBlock;
    uint32 endBlock;
}

library PoolLib {
    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    function zero() internal pure returns (Pool memory) {
        return Pool({
            amount: 0,
            startBlock: 0,
            endBlock: 0
        });
    }

    function head(Pool[] storage checkpoints) internal view returns (Pool memory) {
        if (checkpoints.length > 0) {
            return checkpoints[checkpoints.length - 1];
        } else {
            return zero();
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 MUTATE
    //////////////////////////////////////////////////////////////*/

    function increase(Pool[] storage checkpoints, uint256 delta) internal returns (Pool memory pool) {
        uint256 length = checkpoints.length;

        if (length > 0) {
            pool = push(
                checkpoints,
                checkpoints[length - 1].amount + delta
            );
        } else {
            pool = push(
                checkpoints,
                delta
            );
        }
    }

    function decrease(Pool[] storage checkpoints, uint256 delta) internal returns (Pool memory pool) {
        uint256 length = checkpoints.length;

        if (length > 0) {
            pool = push(
                checkpoints,
                checkpoints[length - 1].amount - delta
            );
        } else {
            revert("ValidatorLib: arithmetic underflow");
        }
    }

    function push(Pool[] storage checkpoints, uint256 amount) internal returns (Pool memory pool) {
        uint256 length = checkpoints.length;

        if (length > 0 && checkpoints[length - 1].startBlock == block.number) {
            checkpoints[length - 1].amount = uint256(amount);
            pool = head(checkpoints);
        } else {
            if (length > 0) {
                checkpoints[length - 1].endBlock = uint32(block.number) - uint32(1);
                checkpoints.push(
                    pool = Pool({
                        amount: uint256(amount),
                        startBlock: uint32(block.number),
                        endBlock: uint32(0)
                    })
                );
            } else {
                checkpoints.push(
                    pool = Pool({
                        amount: uint256(amount),
                        startBlock: uint32(block.number),
                        endBlock: uint32(0)
                    })
                );
            }
        }
    }
}
