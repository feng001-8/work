# Sepolia 测试网委托存款测试

这个测试文件用于在 Sepolia 测试网上验证委托存款功能。

## 配置步骤

### 1. 修改测试文件中的配置

在 `delegateDeposit.test.ts` 文件中，您需要替换以下占位符：

#### 私钥配置
```typescript
// 替换为您的实际私钥
const ownerAccount = privateKeyToAccount('YOUR_OWNER_PRIVATE_KEY' as `0x${string}`)
const delegateAccount = privateKeyToAccount('YOUR_DELEGATE_PRIVATE_KEY' as `0x${string}`)
```

#### 合约地址配置
```typescript
// 替换为您在 Sepolia 上部署的实际合约地址
const TOKEN_ADDRESS = 'YOUR_TOKEN_CONTRACT_ADDRESS' as `0x${string}`
const TOKENBANK_ADDRESS = 'YOUR_TOKENBANK_CONTRACT_ADDRESS' as `0x${string}`
```

#### RPC URL 配置
```typescript
// 替换为您的 Infura/Alchemy 等 RPC 端点
const SEPOLIA_RPC_URL = 'https://sepolia.infura.io/v3/YOUR_PROJECT_ID'
```

### 2. 获取 Sepolia RPC URL

您可以从以下服务提供商获取免费的 Sepolia RPC URL：

- **Infura**: https://infura.io/
  - 注册账户后创建项目
  - 获取项目 ID
  - RPC URL 格式：`https://sepolia.infura.io/v3/YOUR_PROJECT_ID`

- **Alchemy**: https://www.alchemy.com/
  - 注册账户后创建应用
  - 选择 Sepolia 网络
  - 获取 HTTP URL

- **公共 RPC**（不推荐生产环境）:
  - `https://rpc.sepolia.org`
  - `https://sepolia.gateway.tenderly.co`

### 3. 准备测试账户

确保您的测试账户：
1. 有足够的 Sepolia ETH 用于 gas 费用
2. 有足够的测试代币用于存款测试
3. 已经部署了 MyToken 和 TokenBank 合约

### 4. 运行测试

配置完成后，运行以下命令：

```bash
# 在 frontend 目录下
npm test delegateDeposit.test.ts
```

或者运行所有测试：

```bash
npm test
```

## 测试内容

这个测试将验证：

1. ✅ 授权者代币余额正确减少
2. ✅ 授权者银行存款余额正确增加
3. ✅ 银行总存款正确增加
4. ✅ 委托存款交易成功执行

## 注意事项

- 请确保私钥安全，不要提交到版本控制系统
- Sepolia 测试网交易需要等待区块确认，可能需要几秒到几分钟
- 如果测试失败，请检查账户余额、合约地址和网络连接
- 建议使用环境变量来管理敏感信息

## 环境变量配置（推荐）

为了安全起见，建议使用环境变量：

1. 创建 `.env` 文件：
```bash
OWNER_PRIVATE_KEY=0x...
DELEGATE_PRIVATE_KEY=0x...
TOKEN_CONTRACT_ADDRESS=0x...
TOKENBANK_CONTRACT_ADDRESS=0x...
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/...
```

2. 在测试文件中使用：
```typescript
const ownerAccount = privateKeyToAccount(process.env.OWNER_PRIVATE_KEY as `0x${string}`)
```

记住将 `.env` 文件添加到 `.gitignore` 中！