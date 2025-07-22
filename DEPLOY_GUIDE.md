# 🚀 NFT市场和TokenBank综合部署指南

这个指南将帮助您一键部署NFT市场和TokenBank的完整开发环境。

## 📋 前置要求

确保您已经安装了以下工具：

- **Foundry** (anvil, forge, cast)
- **Node.js** 和 **npm**
- **jq** (JSON处理工具)
- **curl**

## 🎯 快速开始

### 1. 一键部署所有合约

```bash
./deploy-all.sh
```

这个脚本将自动完成：
- ✅ 启动Anvil本地网络 (端口8545)
- ✅ 编译所有智能合约
- ✅ 部署NFT市场合约 (ERC20, SimpleNFT, NFTMarket)
- ✅ 部署TokenBank合约 (ERC20, TokenBank)
- ✅ 更新前端配置文件
- ✅ 验证部署结果
- ✅ 保存部署信息

### 2. 启动前端开发服务器

```bash
cd frontend
npm run dev
```

## 🔧 脚本选项

```bash
# 显示帮助信息
./deploy-all.sh --help

# 跳过清理步骤（保留之前的Anvil进程）
./deploy-all.sh --no-cleanup

# 跳过验证步骤（加快部署速度）
./deploy-all.sh --no-verify
```

## 📱 配置MetaMask

部署完成后，按照以下步骤配置MetaMask：

### 添加Anvil网络
1. 打开MetaMask
2. 点击网络下拉菜单
3. 选择"添加网络"
4. 填入以下信息：
   - **网络名称**: Anvil Local
   - **RPC URL**: `http://127.0.0.1:8545`
   - **链ID**: `31337`
   - **货币符号**: `ETH`

### 导入测试账户
1. 点击账户图标
2. 选择"导入账户"
3. 输入私钥：`0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

## 🎮 测试功能

### NFT市场功能
1. **铸造NFT**: 使用SimpleNFT合约铸造新的NFT
2. **授权NFT**: 授权NFT市场合约操作您的NFT
3. **上架NFT**: 设置价格并上架NFT到市场
4. **购买NFT**: 使用ERC20代币购买其他用户的NFT
5. **取消上架**: 取消自己上架的NFT

### TokenBank功能
1. **存款**: 将ERC20代币存入银行合约
2. **取款**: 从银行合约取出代币
3. **查看余额**: 查看在银行中的代币余额

## 📁 生成的文件

部署完成后，会生成以下文件：

- `deployment_info.json` - 完整的部署信息
- `anvil.log` - Anvil网络日志
- `.anvil_pid` - Anvil进程ID
- `frontend/src/lib/contracts.ts.backup` - 前端配置备份

## 🔍 故障排除

### Anvil启动失败
```bash
# 检查端口是否被占用
lsof -i :8545

# 强制清理Anvil进程
pkill -f anvil
```

### 合约部署失败
```bash
# 检查Foundry版本
forge --version

# 重新编译合约
forge clean && forge build
```

### 前端连接失败
1. 确保Anvil网络正在运行
2. 检查MetaMask网络配置
3. 确认合约地址已正确更新

## 🛑 停止服务

```bash
# 停止Anvil网络
pkill -f anvil

# 或者使用保存的PID
kill $(cat .anvil_pid)
```

## 📊 合约地址查看

部署完成后，可以通过以下方式查看合约地址：

```bash
# 查看完整部署信息
cat deployment_info.json

# 查看前端配置
grep -A 10 "LOCALHOST:" frontend/src/lib/contracts.ts
```

## 🔄 重新部署

如果需要重新部署：

```bash
# 完全重新部署
./deploy-all.sh

# 或者手动清理后部署
pkill -f anvil
rm -f anvil.log .anvil_pid deployment_info.json
./deploy-all.sh
```

---

**注意**: 每次重启Anvil网络都会清空所有数据，包括账户余额和合约状态。如果需要持久化数据，请考虑使用测试网络。