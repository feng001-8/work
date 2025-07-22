import { createConfig, http } from 'wagmi'
import { sepolia, localhost } from 'wagmi/chains'
import { metaMask, injected } from 'wagmi/connectors'

// 自定义本地链配置
const customLocalhost = {
  ...localhost,
  id: 31337, // 修正链ID为Anvil的默认值
  rpcUrls: {
    default: {
      http: ['http://127.0.0.1:8545', 'http://localhost:8545'],
    },
    public: {
      http: ['http://127.0.0.1:8545', 'http://localhost:8545'],
    },
  },
}

export const config = createConfig({
  chains: [sepolia, customLocalhost],
  connectors: [
    metaMask(),
    injected(),
  ],
  transports: {
    [sepolia.id]: http(),
    [customLocalhost.id]: http('http://127.0.0.1:8545'),
  },
})

export const chains = [sepolia, customLocalhost]