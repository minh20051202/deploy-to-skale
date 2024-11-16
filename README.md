## Install Foundry

```bash

curl -L https://foundry.paradigm.xyz | bash ##then run

foundryup

```

## Install libraries

```bash

forge install foundry-rs/forge-std --no--commit

forge install OpenZeppelin/openzeppelin-contracts --no-commit

forge install Cyfrin/foundry-devops --no-commit

```

## Deployment

First, import private key

```bash

cast wallet import defaultKey --interactive

```

Second, set the rpc url in .env file, for example:

```
SKALE_TITAN_HUB_RPC_URL=https://testnet.skalenodes.com/v1/aware-fake-trim-testnet
```

run

```bash

source .env

```

then deploy MyNFT contract, replace 0x755... with your public key

```bash

forge script DeployMyNFT --account defaultKey --sender 0x755AC4E90c24135f1B7f73AeEA6a7ff42b07dd94 --rpc-url $SKALE_TITAN_HUB_RPC_URL --broadcast --legacy

```
