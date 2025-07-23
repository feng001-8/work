import { useAccount, useReadContract } from 'wagmi'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card'
import { Button } from '../ui/button'
import { formatEther } from '../../lib/utils'
import { TOKEN_BANK_ABI, ERC20_ABI } from '../../lib/contracts'
import { Coins, Wallet, Building2, RefreshCw } from 'lucide-react'
import { useState } from 'react'

interface BalanceCardProps {
  tokenBankAddress: string
  tokenAddress: string
}

export function BalanceCard({ tokenBankAddress, tokenAddress }: BalanceCardProps) {
  const { address } = useAccount()
  const [isRefreshing, setIsRefreshing] = useState(false)

  // 读取用户代币余额
  const { data: tokenBalance, refetch: refetchTokenBalance } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
      refetchInterval: 5000, // 每5秒自动刷新
    },
  })

  // 读取用户在银行的余额
  const { data: bankBalance, refetch: refetchBankBalance } = useReadContract({
    address: tokenBankAddress as `0x${string}`,
    abi: TOKEN_BANK_ABI,
    functionName: 'getBankBalance',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
      refetchInterval: 5000, // 每5秒自动刷新
    },
  })

  // 读取银行总存款
  const { data: totalDeposits, refetch: refetchTotalDeposits } = useReadContract({
    address: tokenBankAddress as `0x${string}`,
    abi: TOKEN_BANK_ABI,
    functionName: 'getTotalDeposits',
    query: {
      refetchInterval: 5000, // 每5秒自动刷新
    },
  })

  // 读取代币信息 (移除未使用的 tokenName)

  const { data: tokenSymbol } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'symbol',
  })

  // 手动刷新所有数据
  const handleRefresh = async () => {
    setIsRefreshing(true)
    try {
      await Promise.all([
        refetchTokenBalance(),
        refetchBankBalance(),
        refetchTotalDeposits()
      ])
    } catch (error) {
      console.error('刷新数据失败:', error)
    } finally {
      setIsRefreshing(false)
    }
  }

  if (!address) {
    return (
      <Card className="w-full">
        <CardHeader>
          <CardTitle>余额信息</CardTitle>
          <CardDescription>请先连接钱包查看余额</CardDescription>
        </CardHeader>
      </Card>
    )
  }

  return (
    <div className="space-y-6 w-full">
      {/* 刷新按钮 */}
      <div className="flex justify-between items-center p-4 bg-gradient-to-r from-primary/5 to-accent/5 rounded-lg border border-primary/20">
        <h2 className="text-xl font-semibold flex items-center gap-3">
          <div className="p-2 bg-primary/10 rounded-lg">
            <Wallet className="h-5 w-5 text-primary" />
          </div>
          余额信息
        </h2>
        <Button 
          variant="outline" 
          size="lg" 
          onClick={handleRefresh}
          disabled={isRefreshing}
          className="hover-lift glass-effect font-medium"
        >
          <RefreshCw className={`h-5 w-5 mr-2 ${isRefreshing ? 'animate-spin' : ''}`} />
          {isRefreshing ? '刷新中...' : '刷新'}
        </Button>
      </div>
      
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
      {/* 代币余额 */}
      <Card className="glass-effect hover-lift animate-fade-in border-primary/20">
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3 bg-gradient-to-br from-secondary/30 to-muted/20">
          <CardTitle className="text-sm font-medium flex items-center gap-2">
            <div className="w-2 h-2 bg-primary rounded-full animate-pulse"></div>
            钱包余额
          </CardTitle>
          <div className="p-2 bg-primary/10 rounded-lg">
            <Wallet className="h-4 w-4 text-primary" />
          </div>
        </CardHeader>
        <CardContent className="pt-4">
          <div className="text-2xl font-bold text-foreground">
            {tokenBalance ? formatEther(tokenBalance as bigint) : '0'}
          </div>
          <p className="text-sm text-muted-foreground font-medium mt-2">
            {tokenSymbol || 'Token'} 代币
          </p>
        </CardContent>
      </Card>

      {/* 银行存款余额 */}
      <Card className="glass-effect hover-lift animate-fade-in border-success/20">
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3 bg-gradient-to-br from-success/10 to-success/5">
          <CardTitle className="text-sm font-medium flex items-center gap-2">
            <div className="w-2 h-2 bg-success rounded-full animate-pulse"></div>
            银行存款
          </CardTitle>
          <div className="p-2 bg-success/10 rounded-lg">
            <Building2 className="h-4 w-4 text-success" />
          </div>
        </CardHeader>
        <CardContent className="pt-4">
          <div className="text-2xl font-bold text-success">
            {bankBalance ? formatEther(bankBalance as bigint) : '0'}
          </div>
          <p className="text-sm text-success/80 font-medium mt-2">
            您在 TokenBank 的存款
          </p>
        </CardContent>
      </Card>

      {/* 银行总存款 */}
      <Card className="glass-effect hover-lift animate-fade-in border-accent/20">
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3 bg-gradient-to-br from-accent/10 to-accent/5">
          <CardTitle className="text-sm font-medium flex items-center gap-2">
            <div className="w-2 h-2 bg-accent rounded-full animate-pulse"></div>
            银行总存款
          </CardTitle>
          <div className="p-2 bg-accent/10 rounded-lg">
            <Coins className="h-4 w-4 text-accent" />
          </div>
        </CardHeader>
        <CardContent className="pt-4">
          <div className="text-2xl font-bold text-accent">
            {totalDeposits ? formatEther(totalDeposits as bigint) : '0'}
          </div>
          <p className="text-sm text-accent/80 font-medium mt-2">
            TokenBank 总锁定量
          </p>
        </CardContent>
      </Card>
      </div>
    </div>
  )
}