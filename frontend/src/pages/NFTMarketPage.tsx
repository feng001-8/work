import React from 'react'
import { useAccount } from 'wagmi'
import { ShoppingBag, Sparkles, Palette } from 'lucide-react'
import { WalletConnect } from '../components/wallet/WalletConnect'
import NFTMarketDemo from '../components/nft/NFTMarketDemo'
import NFTMarketEventListener from '../components/nft/NFTMarketEventListener'
import { DebugInfo } from '../components/DebugInfo'

const NFTMarketPage: React.FC = () => {
  const { isConnected } = useAccount()

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-background to-secondary/5">
      {/* Hero Header */}
      <div className="relative overflow-hidden bg-gradient-to-r from-primary/10 via-accent/10 to-primary/5 border-b border-border/50">
        <div className="absolute inset-0 bg-grid-pattern opacity-5"></div>
        <div className="container mx-auto px-4 py-12 relative">
          <div className="max-w-4xl mx-auto text-center animate-fade-in">
            <div className="flex items-center justify-center gap-3 mb-6">
              <div className="relative">
                <ShoppingBag className="h-12 w-12 text-primary animate-pulse-glow" />
                <Sparkles className="h-6 w-6 text-accent absolute -top-1 -right-1 animate-bounce-gentle" />
              </div>
              <h1 className="text-5xl font-bold bg-gradient-to-r from-primary via-accent to-primary bg-clip-text text-transparent">
                NFT 艺术市场
              </h1>
            </div>
            <p className="text-xl text-muted-foreground mb-8 animate-slide-up">
              探索、交易和收藏独特的数字艺术品
            </p>
            <div className="flex items-center justify-center gap-2 text-sm text-muted-foreground animate-scale-in">
              <Palette className="h-4 w-4" />
              <span>去中心化 • 安全 • 透明</span>
            </div>
          </div>
        </div>
      </div>

      <div className="container mx-auto px-4 py-8">
        <div className="max-w-7xl mx-auto space-y-8">
          {/* 钱包连接 */}
          {!isConnected && (
            <div className="flex justify-center animate-fade-in">
              <div className="glass-effect p-8 rounded-2xl border border-border/50 backdrop-blur-sm">
                <div className="text-center mb-6">
                  <h2 className="text-2xl font-semibold mb-2">连接钱包开始交易</h2>
                  <p className="text-muted-foreground">连接您的Web3钱包以访问NFT市场功能</p>
                </div>
                <WalletConnect />
              </div>
            </div>
          )}

          {/* 主要内容 */}
          {isConnected && (
            <div className="animate-fade-in space-y-8">
              {/* 调试信息 */}
              <div className="animate-slide-up">
                <DebugInfo />
              </div>
              
              {/* NFT市场演示和事件监听 */}
              <div className="grid grid-cols-1 xl:grid-cols-2 gap-8 animate-scale-in">
                <div className="hover-lift">
                  <NFTMarketDemo />
                </div>
                <div className="hover-lift">
                  <NFTMarketEventListener />
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export default NFTMarketPage