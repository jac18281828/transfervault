# Foundry and Store

A simple working Smart Contract (Ethereum) using Foundry and Docker


Things to try:

Deploy the smart contract 


1. forge create StoreNumber --contracts contracts/StoreNumber.sol --private-key ***** --rpc-url http://ethnode:8545

```
Compiler run successful
Deployer: 0x6ceb0bf1f28ca4165d5c0a04f61dc733987ed6ad
Deployed to: 0xd050519a201b4b990711922ba72299ab5669bea4
Transaction hash: 0xc75e19cd13bf449a8f406e26308315b96fbb3013b367adce7a15417375d7286a
```

2. cast call 0xd050519a201b4b990711922ba72299ab5669bea4 "get()" --rpc-url http://ethnode:8545
```
0x0000000000000000000000000000000000000000000000000000000000000000
```
3. cast send 0xd050519a201b4b990711922ba72299ab5669bea4 "set(uint)" --rpc-url http://ethnode:8545 --private-key ***** 300
```
blockHash               0x13158f054b2711bb7ff57109ab51726c0bc700d92a4f1dc21a9faa5d63d25e02
blockNumber             7152730
contractAddress         
cumulativeGasUsed       99795
effectiveGasPrice       3000000007
gasUsed                 43506
logs                    []
logsBloom               0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
root                    
status                  1
transactionHash         0x455030fe3b9de9ddeefc2af42051f37ae439b1e32798fd81785926c43190e70f
transactionIndex        1
type                    2
```

4. cast call 0xd050519a201b4b990711922ba72299ab5669bea4 "get()" --rpc-url http://ethnode:8545
```
0x000000000000000000000000000000000000000000000000000000000000012c
```
# transfervault
