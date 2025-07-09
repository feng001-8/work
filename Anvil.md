## Cast 和 Anvil


```bash
// 模拟主链
anvil --fork-url https://eth-mainnet.alchemyapi.io/v2/YOUR_API_KEY
```
> 拿到部署的合约地址  
>
>  Contract created: 0x251dda90Cb94f5F9F29c9cb59FA6A0CF07049632 


```bash
# 部署你的合约到分叉网络
# 使用私钥部署
forge script script/Counter.s.sol --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY//用前面创建的私钥就可以了 --broadcast
```

```bash
# 例如调用 add 函数
cast send NEW_CONTRACT_ADDRESS//就是上面的合约地址 "add(uint256)" 10 --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

```bash
#检查值
cast call NEW_CONTRACT_ADDRESS "get()" --rpc-url http://localhost:8545
```

