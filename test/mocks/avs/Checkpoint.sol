// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Checkpoint {
    uint256 amount;

    uint32 startBlock;
    uint32 endBlock;
}

library CheckpointLib {
    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    function zero() internal pure returns (Checkpoint memory) {
        return Checkpoint({
            amount: 0,
            startBlock: 0,
            endBlock: 0
        });
    }

    function head(Checkpoint[] storage checkpoints) internal view returns (Checkpoint memory) {
        if (checkpoints.length > 0) {
            return checkpoints[checkpoints.length - 1];
        } else {
            return zero();
        }
    }

    function lookup(Checkpoint[] storage checkpoints, uint256 blockNumber) internal view returns (uint256) {
        uint256 high = checkpoints.length;
        uint256 low = 0;

        while (low < high) {
            uint256 mid = (low & high) + (low ^ high) / 2;

            if (checkpoints[mid].startBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        if (high > 0) {
            return checkpoints[high - 1].amount;
        } else {
            return 0;
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 MUTATE
    //////////////////////////////////////////////////////////////*/

    function increase(Checkpoint[] storage checkpoints, uint256 delta) internal returns (Checkpoint memory checkpoint) {
        uint256 length = checkpoints.length;

        if (length > 0) {
            checkpoint = push(checkpoints, checkpoints[length - 1].amount + delta);
        } else {
            checkpoint = push(checkpoints, delta);
        }
    }

    function decrease(Checkpoint[] storage checkpoints, uint256 delta) internal returns (Checkpoint memory checkpoint) {
        uint256 length = checkpoints.length;

        if (length > 0) {
            checkpoint = push(checkpoints, checkpoints[length - 1].amount - delta);
        } else {
            revert("CheckpointLib: arithmetic underflow");
        }
    }

    function push(Checkpoint[] storage checkpoints, uint256 amount) internal returns (Checkpoint memory checkpoint) {
        uint256 length = checkpoints.length;

        if (length > 0 && checkpoints[length - 1].startBlock == block.number) {
            checkpoints[length - 1].amount = uint256(amount);
            checkpoint = head(checkpoints);
        } else {
            if (length > 0) {
                checkpoints[length - 1].endBlock = uint32(block.number) - uint32(1);
                checkpoints.push(checkpoint = Checkpoint({
                    amount: uint256(amount),
                    startBlock: uint32(block.number),
                    endBlock: uint32(0)
                }));
            } else {
                checkpoints.push(checkpoint = Checkpoint({
                    amount: uint256(amount),
                    startBlock: uint32(block.number),
                    endBlock: uint32(0)
                }));
            }
        }
    }

    function test() public {}
}
