# node-delegation-contracts

This repository includes the contracts of node-delegation product.

## test & compile & deploy

First, install [foundryup](https://book.getfoundry.sh/getting-started/installation).

Then, install dependencies:

```sh
forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit
forge install OpenZeppelin/openzeppelin-foundry-upgrades --no-commit
forge install foundry-rs/forge-std --no-commit
```

### test

```sh
forge clean
forge test
```

### compile

```sh
forge clean
forge build
```

### deploy

```sh
forge cache clean
forge clean

DEPLOYMENT_OUTFILE=script/deployment-dev.json MEMO_TOKEN=$MEMO_TOKEN forge script script/Deploy.s.sol:Deploy --private-key $PRIVATE_KEY --broadcast --rpc-url $RPC_URL --slow --legacy --optimize
```

The deployed contract addresses will be saved at $DEPLOYMENT_OUTFILE.

### upgrade

```sh
forge cache clean
forge clean
forge build

DEPLOYMENT_OUTFILE=script/deployment-dev.json DELMEMO_PROXY=$DELMEMO_PROXY forge script script/Upgrade.s.sol:Upgrade --private-key $PRIVATE_KEY --broadcast --rpc-url $RPC_URL --slow --legacy --optimize
```

The new implementation contract addresses will be saved at $DEPLOYMENT_OUTFILE.

## abi

solc_version = "0.8.22"

```sh
solc --abi --base-path . --include-path lib/ @openzeppelin/contracts/=lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/ @openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/ src/Delegation.sol -o abi/ --overwrite

solc --abi --base-path . --include-path lib/ @openzeppelin/contracts/=lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/ @openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/ src/DelMEMO.sol -o abi/ --overwrite

solc --abi --base-path . --include-path lib/ @openzeppelin/contracts/=lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/ @openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/ src/LicenseNFT.sol -o abi/ --overwrite

solc --abi --base-path . --include-path lib/ @openzeppelin/contracts/=lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/ @openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/ src/Settlement.sol -o abi/ --overwrite
```

## contract address

dev chain: `./script/deployment-dev.json`

## version history

current version: 0.1.0
