import React, { useState } from 'react'
import { useAccount } from 'wagmi'
import { Wallet, Key, Send } from 'lucide-react'
import { WalletConnect } from '../components/wallet/WalletConnect'
import { PrivateKeyGenerator, GeneratedWallet } from '../components/wallet/PrivateKeyGenerator'
import { BalanceQuery } from '../components/wallet/BalanceQuery'
import { ERC20Transfer } from '../components/wallet/ERC20Transfer'
import { NetworkStatus } from '../components/wallet/NetworkStatus'

const WalletPage: React.FC = () => {
  const { isConnected } = useAccount()
  const [generatedWallet, setGeneratedWallet] = useState<GeneratedWallet | null>(null)

  const handleWalletGenerated = (wallet: GeneratedWallet) => {
    setGeneratedWallet(wallet)
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-background to-secondary/5">
      {/* Hero Header */}
      <div className="relative overflow-hidden bg-gradient-to-r from-primary/10 via-accent/10 to-primary/5 border-b border-border/50">
        <div className="absolute inset-0 bg-grid-pattern opacity-5"></div>
        <div className="container mx-auto px-4 py-12 relative">
          <div className="max-w-4xl mx-auto text-center animate-fade-in">
            <div className="flex items-center justify-center gap-3 mb-6">
              <div className="relative">
                <Wallet className="h-12 w-12 text-primary animate-pulse-glow" />
                <Key className="h-6 w-6 text-accent absolute -top-1 -right-1 animate-bounce-gentle" />
              </div>
              <h1 className="text-5xl font-bold bg-gradient-to-r from-primary via-accent to-primary bg-clip-text text-transparent">
                Web3 钱包
              </h1>
            </div>
            <p className="text-xl text-muted-foreground mb-8 animate-slide-up">
              生成私钥、查询余额、构建和发送ERC20转账交易
            </p>
            <div className="flex items-center justify-center gap-2 text-sm text-muted-foreground animate-scale-in">
              <Send className="h-4 w-4" />
              <span>安全 • 去中心化 • Sepolia测试网络</span>
            </div>
          </div>
        </div>
      </div>

      <div className="container mx-auto px-4 py-8">
        <div className="max-w-7xl mx-auto space-y-8">
          {/* 网络状态 */}
          <NetworkStatus />

          {/* 钱包连接提示 */}
          {!isConnected && (
            <div className="flex justify-center animate-fade-in">
              <div className="glass-effect p-8 rounded-2xl border border-border/50 backdrop-blur-sm">
                <div className="text-center mb-6">
                  <h2 className="text-2xl font-semibold mb-2">连接钱包开始使用</h2>
                  <p className="text-muted-foreground">连接您的Web3钱包以使用完整功能</p>
                </div>
                <WalletConnect />
              </div>
            </div>
          )}

          {/* 主要功能区域 */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            {/* 1. 生成私钥 */}
            <PrivateKeyGenerator onWalletGenerated={handleWalletGenerated} />

            {/* 2. 查询余额 */}
            <BalanceQuery defaultAddress={generatedWallet?.address} />
          </div>

          {/* 3. ERC20转账 */}
          <ERC20Transfer wallet={generatedWallet} />
        </div>
      </div>
    </div>
  )
}

export default WalletPage