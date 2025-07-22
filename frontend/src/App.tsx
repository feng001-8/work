import { useState } from 'react'
import { useAccount, useChainId } from 'wagmi'
import { WalletConnect } from '@/components/WalletConnect'
import { BalanceCard } from '@/components/BalanceCard'

import { DepositForm } from '@/components/DepositForm'
import { WithdrawForm } from '@/components/WithdrawForm'
import { TransactionHistory } from '@/components/TransactionHistory'
import { DebugInfo } from '@/components/DebugInfo'
import { Toaster } from '@/components/ui/toaster'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Button } from '@/components/ui/button'
import { CONTRACTS } from '@/lib/contracts'
import { Building2, Settings } from 'lucide-react'

function App() {
  const { isConnected } = useAccount()
  const chainId = useChainId()
  const [showSettings, setShowSettings] = useState(false)
  const [customTokenBank, setCustomTokenBank] = useState('')
  const [customToken, setCustomToken] = useState('')
  const [useCustomAddresses, setUseCustomAddresses] = useState(false)

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
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b">
        <div className="container mx-auto px-4 py-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Building2 className="h-8 w-8" />
              <h1 className="text-3xl font-bold">TokenBank DApp</h1>
            </div>
            <div className="flex items-center gap-4">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setShowSettings(!showSettings)}
              >
                <Settings className="h-4 w-4 mr-2" />
                设置
              </Button>
              {chainId && (
                <div className="text-sm text-muted-foreground">
                  网络: {chainId === 31337 ? 'Localhost' : chainId === 11155111 ? 'Sepolia' : `Chain ${chainId}`}
                </div>
              )}
            </div>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8">
        <div className="max-w-6xl mx-auto space-y-8">
          {/* 设置面板 */}
          {showSettings && (
            <Card>
              <CardHeader>
                <CardTitle>合约设置</CardTitle>
                <CardDescription>
                  配置 TokenBank 和 ERC20 代币合约地址
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center space-x-2">
                  <input
                    type="checkbox"
                    id="use-custom"
                    checked={useCustomAddresses}
                    onChange={(e) => setUseCustomAddresses(e.target.checked)}
                    className="rounded"
                  />
                  <Label htmlFor="use-custom">使用自定义合约地址</Label>
                </div>
                
                {useCustomAddresses && (
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="token-bank-address">TokenBank 合约地址</Label>
                      <Input
                        id="token-bank-address"
                        placeholder="0x..."
                        value={customTokenBank}
                        onChange={(e) => setCustomTokenBank(e.target.value)}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="token-address">ERC20 代币地址</Label>
                      <Input
                        id="token-address"
                        placeholder="0x..."
                        value={customToken}
                        onChange={(e) => setCustomToken(e.target.value)}
                      />
                    </div>
                  </div>
                )}
                
                <div className="text-sm text-muted-foreground">
                  <p>当前使用的地址:</p>
                  <p>TokenBank: {tokenBank}</p>
                  <p>ERC20 Token: {token}</p>
                </div>
              </CardContent>
            </Card>
          )}

          {/* 钱包连接 */}
          {!isConnected && (
            <div className="flex justify-center">
              <WalletConnect />
            </div>
          )}

          {/* 主要内容 */}
          {isConnected && (
            <>
              {/* 调试信息 */}
              <DebugInfo />
              
              {/* 地址验证警告 */}
              {!hasValidAddresses && (
                <Card className="border-destructive">
                  <CardHeader>
                    <CardTitle className="text-destructive">配置错误</CardTitle>
                    <CardDescription>
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
                  <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
                    <DepositForm 
                      tokenBankAddress={tokenBank}
                      tokenAddress={token}
                    />
                    <WithdrawForm 
                      tokenBankAddress={tokenBank}
                    />
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
      </main>

      {/* Footer */}
      <footer className="border-t mt-16">
        <div className="container mx-auto px-4 py-6">
          <div className="text-center text-sm text-muted-foreground">
            <p>TokenBank DApp - 基于 React + Viem + shadcn/ui 构建</p>
          </div>
        </div>
      </footer>

      <Toaster />
    </div>
  )
}

export default App