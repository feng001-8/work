# TokenBank DApp 前端

这是一个基于 React + Viem + shadcn/ui 构建的 TokenBank 智能合约前端界面。

## 功能特性

- 🔗 **钱包连接**: 支持 MetaMask 等主流钱包
- 💰 **余额查看**: 实时显示代币余额、银行存款和总存款
- 📥 **存款功能**: 将 ERC20 代币存入 TokenBank
- 📤 **取款功能**: 从 TokenBank 取出代币
- 📊 **交易历史**: 查看存款和取款记录
- 🎨 **现代化 UI**: 使用 shadcn/ui 组件库
- 📱 **响应式设计**: 支持桌面和移动端

## 技术栈

- **前端框架**: React 18 + TypeScript
- **构建工具**: Vite
- **Web3 库**: Viem + Wagmi
- **UI 组件**: shadcn/ui
- **样式**: Tailwind CSS
- **状态管理**: React Query + Wagmi

## 快速开始

### 1. 安装依赖

```bash
npm install
# 或
yarn install
```

### 2. 配置环境变量 (可选)

复制 `.env.example` 到 `.env` 并配置相关变量：

```bash
cp .env.example .env
```

### 3. 配置合约地址

在 `src/lib/contracts.ts` 中更新合约地址：

```typescript
export const CONTRACTS = {
  SEPOLIA: {
    TOKEN_BANK: '0x你的TokenBank合约地址',
    ERC20_TOKEN: '0x你的ERC20代币地址',
  },
  LOCALHOST: {
    TOKEN_BANK: '0x你的本地TokenBank合约地址',
    ERC20_TOKEN: '0x你的本地ERC20代币地址',
  }
}
```

### 4. 启动开发服务器

```bash
npm run dev
# 或
yarn dev
```

应用将在 `http://localhost:5173` 启动。

## 项目结构

```
src/
├── components/
│   ├── ui/                 # shadcn/ui 基础组件
│   ├── WalletConnect.tsx   # 钱包连接组件
│   ├── BalanceCard.tsx     # 余额显示组件
│   ├── DepositForm.tsx     # 存款表单组件
│   ├── WithdrawForm.tsx    # 取款表单组件
│   └── TransactionHistory.tsx # 交易历史组件
├── lib/
│   ├── contracts.ts        # 合约 ABI 和地址配置
│   ├── utils.ts           # 工具函数
│   └── wagmi.ts           # Wagmi 配置
├── App.tsx                # 主应用组件
├── main.tsx              # 应用入口
└── index.css             # 全局样式
```

## 使用说明

### 1. 连接钱包

- 点击"连接钱包"按钮
- 选择 MetaMask 或其他支持的钱包
- 确认连接请求

### 2. 查看余额

连接钱包后，您可以看到三个余额卡片：
- **钱包余额**: 您钱包中的 ERC20 代币余额
- **银行存款**: 您在 TokenBank 中的存款余额
- **银行总存款**: TokenBank 合约中的总锁定量

### 3. 存款操作

1. 在存款表单中输入金额
2. 如果是首次存款，需要先授权代币
3. 点击"授权代币"按钮并确认交易
4. 授权完成后，点击"存款"按钮
5. 确认交易并等待区块确认

### 4. 取款操作

1. 在取款表单中输入金额
2. 点击"取款"按钮
3. 确认交易并等待区块确认

### 5. 查看交易历史

在交易历史部分可以看到：
- 最近的存款和取款记录
- 交易时间和金额
- 点击"查看交易"链接可以在区块链浏览器中查看详情

## 网络支持

目前支持以下网络：
- **Sepolia 测试网** (Chain ID: 11155111)
- **本地开发网络** (Chain ID: 31337)

可以通过钱包切换网络，应用会自动适配对应的合约地址。

## 自定义配置

### 添加新网络

在 `src/lib/wagmi.ts` 中添加新的链配置：

```typescript
import { mainnet } from 'wagmi/chains'

const { chains, publicClient } = configureChains(
  [sepolia, localhost, mainnet], // 添加新网络
  [publicProvider()]
)
```

### 添加新的钱包连接器

在 `src/lib/wagmi.ts` 中添加新的连接器：

```typescript
import { WalletConnectConnector } from 'wagmi/connectors/walletConnect'

export const config = createConfig({
  connectors: [
    new MetaMaskConnector({ chains }),
    new WalletConnectConnector({
      chains,
      options: {
        projectId: 'your-project-id',
      },
    }),
  ],
  // ...
})
```

## 构建和部署

### 构建生产版本

```bash
npm run build
# 或
yarn build
```

构建文件将生成在 `dist/` 目录中。

### 部署

可以将 `dist/` 目录部署到任何静态文件托管服务，如：
- Vercel
- Netlify
- GitHub Pages
- IPFS

## 故障排除

### 常见问题

1. **钱包连接失败**
   - 确保已安装 MetaMask 或其他支持的钱包
   - 检查网络连接
   - 尝试刷新页面

2. **合约调用失败**
   - 检查合约地址是否正确
   - 确保连接到正确的网络
   - 检查钱包中是否有足够的 Gas 费

3. **交易失败**
   - 检查代币余额是否足够
   - 确保已正确授权代币（存款时）
   - 检查 Gas 费设置

4. **页面显示异常**
   - 清除浏览器缓存
   - 检查控制台错误信息
   - 确保使用支持的浏览器版本

### 开发调试

启用开发者工具查看详细错误信息：

```bash
# 启动开发服务器并打开浏览器开发者工具
npm run dev
```

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License