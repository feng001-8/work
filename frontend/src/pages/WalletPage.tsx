import React, { useState } from 'react'
import { useAccount } from 'wagmi'
import { Wallet, Key, Send, Sparkles } from 'lucide-react'
import { WalletConnect } from '../components/wallet/WalletConnect'
import { PrivateKeyGenerator, GeneratedWallet } from '../components/wallet/PrivateKeyGenerator'
import { BalanceQuery } from '../components/wallet/BalanceQuery'
import { ERC20Transfer } from '../components/wallet/ERC20Transfer'
import { NetworkStatus } from '../components/wallet/NetworkStatus'
import ParticleBackground from '../components/effects/ParticleBackground'
import FloatingElements from '../components/effects/FloatingElements'
import AnimatedGradient from '../components/effects/AnimatedGradient'

const WalletPage: React.FC = () => {
  const { isConnected } = useAccount()
  const [generatedWallet, setGeneratedWallet] = useState<GeneratedWallet | null>(null)

  const handleWalletGenerated = (wallet: GeneratedWallet) => {
    setGeneratedWallet(wallet)
  }

  return (
    <div className="min-h-screen relative overflow-hidden">
      {/* 动态背景层 */}
      <div className="fixed inset-0 z-0">
        <AnimatedGradient className="opacity-30" />
        <div className="absolute inset-0 bg-gradient-mesh opacity-40" />
        <ParticleBackground 
          particleCount={60} 
          interactive={true}
          colors={['#3b82f6', '#8b5cf6', '#06b6d4', '#10b981', '#f59e0b']}
        />
        <FloatingElements 
          elementCount={12}
          interactive={true}
          colors={['#3b82f6', '#8b5cf6', '#06b6d4', '#ef4444', '#f59e0b']}
        />
      </div>
      
      {/* 主要内容 */}
      <div className="relative z-10">
        {/* Hero Header */}
        <div className="relative overflow-hidden border-b border-border/30">
          <div className="absolute inset-0 bg-dot-pattern opacity-20"></div>
          <div className="glass-effect-strong">
            <div className="container mx-auto px-4 py-16 relative">
              <div className="max-w-4xl mx-auto text-center animate-fade-in">
                <div className="flex items-center justify-center gap-4 mb-8">
                  <div className="relative">
                    <div className="absolute inset-0 animate-pulse-glow rounded-full"></div>
                    <Wallet className="h-16 w-16 text-gradient relative z-10 animate-float" />
                    <Sparkles className="h-8 w-8 text-trae-purple absolute -top-2 -right-2 animate-bounce-gentle" />
                    <Key className="h-6 w-6 text-trae-cyan absolute -bottom-1 -left-1 animate-pulse-glow" />
                  </div>
                  <h1 className="text-6xl font-bold text-gradient text-glow">
                    TRAE 钱包
                  </h1>
                </div>
                <p className="text-2xl text-foreground/80 mb-10 animate-slide-up font-light">
                  下一代 Web3 钱包体验 • 离子级安全 • 量子级速度
                </p>
                <div className="flex items-center justify-center gap-3 text-lg text-muted-foreground animate-scale-in">
                  <div className="flex items-center gap-2 glass-effect px-4 py-2 rounded-full">
                    <Send className="h-5 w-5 text-trae-cyan" />
                    <span>安全传输</span>
                  </div>
                  <div className="flex items-center gap-2 glass-effect px-4 py-2 rounded-full">
                    <Sparkles className="h-5 w-5 text-trae-purple" />
                    <span>去中心化</span>
                  </div>
                  <div className="flex items-center gap-2 glass-effect px-4 py-2 rounded-full">
                    <Key className="h-5 w-5 text-trae-amber" />
                    <span>Sepolia 测试网</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="container mx-auto px-4 py-12">
          <div className="max-w-7xl mx-auto space-y-12">
            {/* 网络状态 */}
            <div className="animate-fade-in">
              <NetworkStatus />
            </div>

            {/* 钱包连接提示 */}
            {!isConnected && (
              <div className="flex justify-center animate-fade-in">
                <div className="glass-effect-strong p-10 rounded-3xl border border-border/30 backdrop-blur-xl hover-lift">
                  <div className="text-center mb-8">
                    <div className="mb-6">
                      <div className="w-20 h-20 mx-auto rounded-full glass-effect flex items-center justify-center mb-4 animate-pulse-glow">
                        <Wallet className="h-10 w-10 text-gradient" />
                      </div>
                      <h2 className="text-3xl font-bold mb-3 text-gradient">连接您的钱包</h2>
                      <p className="text-foreground/70 text-lg">体验下一代 Web3 钱包功能</p>
                    </div>
                  </div>
                  <WalletConnect />
                </div>
              </div>
            )}

            {/* 主要功能区域 */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-10">
              {/* 1. 生成私钥 */}
              <div className="animate-slide-up" style={{ animationDelay: '0.1s' }}>
                <PrivateKeyGenerator onWalletGenerated={handleWalletGenerated} />
              </div>

              {/* 2. 查询余额 */}
              <div className="animate-slide-up" style={{ animationDelay: '0.2s' }}>
                <BalanceQuery defaultAddress={generatedWallet?.address} />
              </div>
            </div>

            {/* 3. ERC20转账 */}
            <div className="animate-slide-up" style={{ animationDelay: '0.3s' }}>
              <ERC20Transfer wallet={generatedWallet} />
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default WalletPage