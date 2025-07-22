# TokenBank 本地部署和测试指南

## 🚀 快速开始

### 1. 启动本地区块链网络

已经为您启动了 Anvil 本地网络：
- **网络地址**: http://localhost:8546
- **Chain ID**: 31337
- **网络名称**: Localhost

### 2. 合约部署信息

✅ **ERC20 代币合约**
- 地址: `0x5FbDB2315678afecb367f032d93F642f64180aa3`
- 名称: BaseERC20
- 符号: MTK
- 小数位: 18

✅ **TokenBank 合约**
- 地址: `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512`
- 管理的代币: 上述 ERC20 代币

### 3. MetaMask 配置

#### 添加本地网络
1. 打开 MetaMask
2. 点击网络下拉菜单
3. 选择「添加网络」
4. 填入以下信息：
   - **网络名称**: Localhost
   - **新 RPC URL**: http://localhost:8546
   - **链 ID**: 31337
   - **货币符号**: ETH
   - **区块浏览器 URL**: (留空)

#### 导入测试账户
1. 在 MetaMask 中点击账户图标
2. 选择「导入账户」
3. 输入私钥: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
4. 这个账户地址是: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`

#### 添加 ERC20 代币
1. 在 MetaMask 中点击「导入代币」
2. 输入代币合约地址: `0x5FbDB2315678afecb367f032d93F642f64180aa3`
3. 代币符号和小数位会自动填充
4. 点击「添加自定义代币」

### 4. 测试数据

✅ **已为测试账户分配代币**
- 账户: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- 余额: 1000 MTK 代币
- ETH 余额: 10000 ETH

### 5. 前端访问

🌐 **前端地址**: http://localhost:5173/

### 6. 测试流程

1. **连接钱包**
   - 确保 MetaMask 连接到 Localhost 网络
   - 使用导入的测试账户

2. **查看余额**
   - 钱包余额应显示 1000 MTK
   - 银行存款应显示 0

3. **存款测试**
   - 输入存款金额（如 100）
   - 点击「授权」按钮
   - 确认 MetaMask 交易
   - 点击「存款」按钮
   - 确认 MetaMask 交易

4. **查看更新后的余额**
   - 钱包余额应减少
   - 银行存款应增加

5. **取款测试**
   - 输入取款金额
   - 点击「取款」按钮
   - 确认 MetaMask 交易

### 7. 故障排除

#### 余额显示为 0
- 确保 MetaMask 连接到正确的网络 (Localhost, Chain ID: 31337)
- 确保使用正确的测试账户
- 确保已添加 ERC20 代币到 MetaMask
- 刷新页面重试

#### 交易失败
- 检查 MetaMask 是否有足够的 ETH 支付 gas 费
- 确保合约地址正确
- 检查 Anvil 是否仍在运行

#### 网络连接问题
- 确保 Anvil 在端口 8546 上运行
- 检查防火墙设置
- 尝试重启 MetaMask

### 8. 其他测试账户

如需更多测试账户，可以使用以下私钥：

```
账户 1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
私钥 1: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

账户 2: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
私钥 2: 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
```

### 9. 重新部署合约

如需重新部署合约：

```bash
# 部署 ERC20 代币
forge create src/ERC20.sol:BaseERC20 --rpc-url http://localhost:8546 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast

# 部署 TokenBank (替换 <ERC20_ADDRESS> 为上一步的地址)
forge create src/TokenBank.sol:TokenBank --rpc-url http://localhost:8546 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast --constructor-args <ERC20_ADDRESS>
```

---

## 🎉 现在您可以开始测试 TokenBank DApp 了！

访问 http://localhost:5173/ 并按照上述步骤配置 MetaMask，您应该能够看到正确的余额并进行存取款操作。