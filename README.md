# Juicebox 721 Distribution Mechanism

## Motivation


## Mechanic

## Architecture

## Deploy

# Install

Quick all-in-one command:

```bash
rm -Rf juice-defifa || true && git clone -n https://github.com/jbx-protocol/juice-defifa && cd juice-defifa && git pull origin main && git checkout FETCH_HEAD && foundryup && git submodule update --init --recursive --force && yarn install && forge test
```

To get set up:

1. Install [Foundry](https://github.com/gakonst/foundry).

```bash
curl -L https://foundry.paradigm.xyz | sh
```

2. Install external lib(s)

```bash
git submodule update --init --recursive --force && yarn install
```

then run

```bash
forge update
```

3. Run tests:

```bash
forge test
```

4. Update Foundry periodically:

```bash
foundryup
```

#### Setup

Configure the .env variables, and add a mnemonic.txt file with the mnemonic of the deployer wallet. The sender address in the .env must correspond to the mnemonic account.

## Goerli

```bash
yarn deploy-goerli
```

## Mainnet

```bash
yarn deploy-mainnet
```

The deployments are stored in ./broadcast

See the [Foundry Book for available options](https://book.getfoundry.sh/reference/forge/forge-create.html).
