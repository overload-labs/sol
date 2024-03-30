// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Metadata {
    uint16 fee; // fee in 0.0001 = 0.01% (1% is `100`), range is `0` to `10000`.
    string name;
    string description;
}
