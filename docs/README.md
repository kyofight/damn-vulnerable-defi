# Damn Vulnerable DeFi — Documentation

This repository contains a collection of Solidity smart contracts and Hardhat tests used to illustrate common DeFi vulnerabilities and patterns. This documentation describes the public APIs of all contracts and shows how to use them with concrete examples.

- For a complete per-contract API reference, see: [Contracts Reference](./CONTRACTS.md)

## Setup

- Node.js LTS and Yarn are recommended
- Install dependencies:

```bash
yarn install
```

## Running Scenarios / Tests

Each scenario has a dedicated test script. You can run them individually using the provided scripts in `package.json`:

```bash
# Examples
yarn unstoppable
yarn truster
yarn naive-receiver
yarn side-entrance
yarn the-rewarder
yarn selfie
yarn compromised
yarn puppet
yarn puppet-v2
yarn free-rider
yarn backdoor
yarn climber
yarn wallet-mining
yarn abi-smuggling
yarn puppet-v3
```

Alternatively, to run any single test directly with Hardhat, run:

```bash
yarn hardhat test test/<scenario>/<scenario>.challenge.js
```

## Project Structure

- `contracts/`: Solidity contracts grouped by scenario
- `test/`: Hardhat tests that demonstrate usage and expected behavior
- `build-uniswap-v1/`: ABIs for Uniswap v1 used by some scenarios

## Contributing

This codebase is intentionally minimal and educational. PRs that improve clarity of examples and documentation are welcome.