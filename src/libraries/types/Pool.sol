// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Pool {
    uint256 active;
    uint256 total;

    uint32 startBlock;
    uint32 endBlock;
}

library PoolLib {
    function zero() internal pure returns (Pool memory) {
        return Pool({
            active: 0,
            total: 0,
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

    function increase(Pool[] storage checkpoints, bool isActive, uint256 delta) internal {
        uint256 length = checkpoints.length;

        if (length > 0) {
            push(
                checkpoints,
                isActive
                    ? checkpoints[length - 1].active + delta
                    : checkpoints[length - 1].active,
                checkpoints[length - 1].total + delta
            );
        } else {
            push(
                checkpoints,
                isActive
                    ? delta
                    : 0,
                delta
            );
        }
    }

    function decrease(Pool[] storage checkpoints, bool isActive, uint256 delta) internal {
        uint256 length = checkpoints.length;

        if (length > 0) {
            push(
                checkpoints,
                isActive
                    ? checkpoints[length - 1].active - delta
                    : checkpoints[length - 1].active,
                checkpoints[length - 1].total - delta
            );
        } else {
            revert("ValidatorLib: arithmetic underflow");
        }
    }

    function push(Pool[] storage checkpoints, uint256 active, uint256 total) internal {
        uint256 length = checkpoints.length;

        if (length > 0 && checkpoints[length - 1].startBlock == block.number) {
            checkpoints[length - 1].active = uint256(active);
            checkpoints[length - 1].total = uint256(total);
        } else {
            if (length > 0) {
                checkpoints[length - 1].endBlock = uint32(block.number) - uint32(1);
                checkpoints.push(
                    Pool({
                        active: uint256(active),
                        total: uint256(total),
                        startBlock: uint32(block.number),
                        endBlock: uint32(0)
                    })
                );
            } else {
                checkpoints.push(
                    Pool({
                        active: uint256(active),
                        total: uint256(total),
                        startBlock: uint32(block.number),
                        endBlock: uint32(0)
                    })
                );
            }
        }
    }
}
