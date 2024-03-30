<div align="center">
  <h1>Overload</h1>
</div>
<p align="center">
  A restaking primitive, built from ground-up.
</p>
<br />

Overload is a permissionless restaking primitive, where you can launch your own AVSs (Actively Validated Services) without needing permission from the core team. Overload takes an approach of being a [canary](https://wiki.polkadot.network/docs/learn-comparisons-kusama#canary-network) primitive (as opposed to stable) for deploying AVSs onchain. This will allow developers to iterate and deploy faster, without having to wait for core team approvals.

By being a canary restaking primitive, Overload will support more tokens than only ETH and LSDs for restaking, in other words, support for assets such as USDT and USDC (or theoretically even memecoins) will be deemed eligible for securing AVSs.

## Build

To build the contracts, run:

```
forge build
```

## Software

The `overload-sol` is a repository that hosts the Solidity code for Overload. The details of a Overload node can be found at `overload-ts`. The management of the onchain contracts is most oftenly done through `overload-cli` to prevent any unintended interactions with the contracts.

### Gossip

For gossiping attestations on Overload we utilize a data availablility network as oppososed to running peer-to-peer nodes. The reasoning is that data availability layers are a form of consensus in packages being sent, and simplifies the networking between nodes. There would be no need to configure IPs or consider nefairous nodes (e.g. a node do not relay attestations to other nodes, or spams the network).

