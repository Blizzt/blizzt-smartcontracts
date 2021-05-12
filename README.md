# Blizzt
## Installation setup

Install truffle
```sh
npm install -g truffle
```

Clone the repo
Install the dependencies
```sh
npm install
```
- Create a file named `.infura` and copy inside your Infura project id
- Create a file named `.secret` and copy inside the seed words of the deployment account

## Compile
First, compile to check everything is working
```sh
truffle compile
```

## Deploy local
First, install [Ganache](https://www.trufflesuite.com/ganache) if it's no installed
Execute the following command in a terminal
```sh
truffle migrate --reset
```

## Run tests
```sh
truffle test
```

## Deploy in localhost (Ganache)
Execute the following command in a terminal
```sh
truffle migrate --reset -f 1 --to 1
```

## Deploy in testnet (Rinkeby)
Execute the following command in a terminal
```sh
truffle migrate --reset --network rinkeby -f 1 --to 1
```

