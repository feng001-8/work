import React, { useState } from 'react'
import { useAccount, useChainId } from 'wagmi'
import { Building2, Settings } from 'lucide-react'
import { Button } from '../components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/ui/card'
import { Input } from '../components/ui/input'
import { Label } from '../components/ui/label'
import { CONTRACTS } from '../lib/contracts'
import { WalletConnect } from '../components/wallet/WalletConnect'
import { BalanceCard } from '../components/tokenbank/BalanceCard'
import { DepositForm } from '../components/tokenbank/DepositForm'
import { WithdrawForm } from '../components/tokenbank/WithdrawForm'
import { TransactionHistory } from '../components/TransactionHistory'
import { DebugInfo } from '../components/DebugInfo'

const TokenBankPage: React.FC = () => {
  const { isConnected } = useAccount()
  const chainId = useChainId()
  const [showSettings, setShowSettings] = useState(false)
  const [useCustomAddresses, setUseCustomAddresses] = useState(false)
  const [customTokenBank, setCustomTokenBank] = useState('')
  const [customToken, setCustomToken] = useState('')

  // 获取合约地址
  const getContractAddresses = () => {
    console.log('Current chainId:', chainId) // 调试信息
    
    if (useCustomAddresses && customTokenBank && customToken) {
      return {
        tokenBank: customTokenBank,
        token: customToken,
      }
    }

    // 根据网络选择默认地址
    if (chainId === 11155111) { // Sepolia
      console.log('Using Sepolia addresses')
      return {
        tokenBank: CONTRACTS.SEPOLIA.TOKEN_BANK,
        token: CONTRACTS.SEPOLIA.ERC20_TOKEN,
      }
    } else if (chainId === 31337) { // Localhost
      console.log('Using Localhost addresses')
      return {
        tokenBank: CONTRACTS.LOCALHOST.TOKEN_BANK,
        token: CONTRACTS.LOCALHOST.ERC20_TOKEN,
      }
    }

    // 默认使用本地地址而不是 Sepolia
    console.log('Using default localhost addresses')
    return {
      tokenBank: CONTRACTS.LOCALHOST.TOKEN_BANK,
      token: CONTRACTS.LOCALHOST.ERC20_TOKEN,
    }
  }

  const { tokenBank, token } = getContractAddresses()
  const isValidAddress = (address: string) => /^0x[a-fA-F0-9]{40}$/.test(address)
  const hasValidAddresses = isValidAddress(tokenBank) && isValidAddress(token)

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-background to-secondary/20">
      {/* Hero Header */}
      <header className="relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-r from-primary/10 via-accent/5 to-primary/10"></div>
        <div className="relative container mx-auto px-4 py-12">
          <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-6">
            <div className="flex items-center gap-4 animate-slide-up">
              <div className="relative">
                <div className="absolute inset-0 bg-primary/20 rounded-2xl blur-xl"></div>
                <div className="relative bg-gradient-to-br from-primary to-accent p-4 rounded-2xl shadow-glow">
                  <Building2 className="h-10 w-10 text-white" />
                </div>
              </div>
              <div>
                <h1 className="text-4xl lg:text-5xl font-bold bg-gradient-to-r from-primary via-accent to-primary bg-clip-text text-transparent">
                  TokenBank
                </h1>
                <p className="text-lg text-muted-foreground mt-2">
                  安全的去中心化代币存储与管理平台
                </p>
              </div>
            </div>
            
            <div className="flex flex-col sm:flex-row items-start sm:items-center gap-4 animate-fade-in">
              <Button
                variant="outline"
                size="lg"
                onClick={() => setShowSettings(!showSettings)}
                className="hover-lift glass-effect"
              >
                <Settings className="h-5 w-5 mr-2" />
                <span className="font-medium">设置</span>
              </Button>
              {chainId && (
                <div className="glass-effect px-4 py-2 rounded-lg">
                  <div className="text-sm font-medium text-foreground">
                    当前网络
                  </div>
                  <div className="text-xs text-muted-foreground">
                    {chainId === 31337 ? '🏠 Localhost' : chainId === 11155111 ? '🔗 Sepolia' : `⚡ Chain ${chainId}`}
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
        
        {/* 装饰性波浪 */}
        <div className="absolute bottom-0 left-0 right-0 h-6 bg-gradient-to-r from-primary/20 via-accent/10 to-primary/20 transform -skew-y-1"></div>
      </header>

      <div className="container mx-auto px-4 py-12">
        <div className="max-w-7xl mx-auto space-y-12">
          {/* 设置面板 */}
          {showSettings && (
            <Card className="glass-effect hover-lift animate-scale-in border-primary/20">
              <CardHeader className="bg-gradient-to-r from-primary/5 to-accent/5 rounded-t-lg">
                <CardTitle className="flex items-center gap-2">
                  <Settings className="h-5 w-5 text-primary" />
                  合约设置
                </CardTitle>
                <CardDescription className="text-base">
                  配置 TokenBank 和 ERC20 代币合约地址
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-6 p-6">
                <div className="flex items-center space-x-3 p-4 bg-secondary/30 rounded-lg">
                  <input
                    type="checkbox"
                    id="use-custom"
                    checked={useCustomAddresses}
                    onChange={(e) => setUseCustomAddresses(e.target.checked)}
                    className="w-4 h-4 text-primary bg-background border-border rounded focus:ring-primary focus:ring-2"
                  />
                  <Label htmlFor="use-custom" className="font-medium cursor-pointer">
                    使用自定义合约地址
                  </Label>
                </div>
                
                {useCustomAddresses && (
                  <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 animate-slide-up">
                    <div className="space-y-3">
                      <Label htmlFor="token-bank-address" className="text-sm font-semibold text-foreground">
                        TokenBank 合约地址
                      </Label>
                      <Input
                        id="token-bank-address"
                        placeholder="0x..."
                        value={customTokenBank}
                        onChange={(e) => setCustomTokenBank(e.target.value)}
                        className="font-mono text-sm"
                      />
                    </div>
                    <div className="space-y-3">
                      <Label htmlFor="token-address" className="text-sm font-semibold text-foreground">
                        ERC20 代币地址
                      </Label>
                      <Input
                        id="token-address"
                        placeholder="0x..."
                        value={customToken}
                        onChange={(e) => setCustomToken(e.target.value)}
                        className="font-mono text-sm"
                      />
                    </div>
                  </div>
                )}
                
                <div className="bg-muted/50 p-4 rounded-lg border border-border/50">
                  <p className="text-sm font-semibold text-foreground mb-3">当前使用的地址:</p>
                  <div className="space-y-2 text-xs font-mono">
                    <div className="flex flex-col sm:flex-row sm:items-center gap-1">
                      <span className="text-muted-foreground min-w-[100px]">TokenBank:</span>
                      <span className="text-foreground break-all">{tokenBank}</span>
                    </div>
                    <div className="flex flex-col sm:flex-row sm:items-center gap-1">
                      <span className="text-muted-foreground min-w-[100px]">ERC20 Token:</span>
                      <span className="text-foreground break-all">{token}</span>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          )}

          {/* 钱包连接 */}
          {!isConnected && (
            <div className="flex justify-center animate-bounce-gentle">
              <div className="text-center space-y-6">
                <div className="mx-auto w-24 h-24 bg-gradient-to-br from-primary to-accent rounded-full flex items-center justify-center shadow-glow">
                  <Building2 className="h-12 w-12 text-white" />
                </div>
                <div className="space-y-2">
                  <h3 className="text-xl font-semibold">连接钱包开始使用</h3>
                  <p className="text-muted-foreground">请连接您的Web3钱包以访问TokenBank功能</p>
                </div>
                <WalletConnect />
              </div>
            </div>
          )}

          {/* 主要内容 */}
          {isConnected && (
            <>
              {/* 调试信息 */}
              <DebugInfo />
              
              {/* 地址验证警告 */}
              {!hasValidAddresses && (
                <Card className="border-destructive/50 bg-destructive/5 animate-scale-in">
                  <CardHeader>
                    <CardTitle className="text-destructive flex items-center gap-2">
                      <div className="w-2 h-2 bg-destructive rounded-full animate-pulse"></div>
                      配置错误
                    </CardTitle>
                    <CardDescription className="text-base">
                      请在设置中配置有效的合约地址，或确保默认地址已正确部署。
                    </CardDescription>
                  </CardHeader>
                </Card>
              )}

              {hasValidAddresses && (
                <>
                  {/* 余额卡片 */}
                  <BalanceCard 
                    tokenBankAddress={tokenBank}
                    tokenAddress={token}
                  />

                  {/* 操作面板 */}
                  <div className="grid grid-cols-1 xl:grid-cols-2 gap-8">
                    <div className="animate-slide-up" style={{animationDelay: '0.1s'}}>
                      <DepositForm 
                        tokenBankAddress={tokenBank}
                        tokenAddress={token}
                      />
                    </div>
                    <div className="animate-slide-up" style={{animationDelay: '0.2s'}}>
                      <WithdrawForm 
                        tokenBankAddress={tokenBank}
                      />
                    </div>
                  </div>

                  {/* 交易历史 */}
                  <TransactionHistory 
                    tokenBankAddress={tokenBank}
                  />
                </>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  )
}

export default TokenBankPage