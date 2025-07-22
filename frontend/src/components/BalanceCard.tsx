import { useAccount, useReadContract } from 'wagmi'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { formatEther } from '@/lib/utils'
import { TOKEN_BANK_ABI, ERC20_ABI } from '@/lib/contracts'
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
    <div className="space-y-4 w-full">
      {/* 刷新按钮 */}
      <div className="flex justify-between items-center">
        <h2 className="text-lg font-semibold">余额信息</h2>
        <Button 
          variant="outline" 
          size="sm" 
          onClick={handleRefresh}
          disabled={isRefreshing}
        >
          <RefreshCw className={`h-4 w-4 mr-2 ${isRefreshing ? 'animate-spin' : ''}`} />
          {isRefreshing ? '刷新中...' : '刷新'}
        </Button>
      </div>
      
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
      {/* 代币余额 */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">
            钱包余额
          </CardTitle>
          <Wallet className="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">
            {tokenBalance ? formatEther(tokenBalance as bigint) : '0'}
          </div>
          <p className="text-xs text-muted-foreground">
            {tokenSymbol || 'Token'} 代币
          </p>
        </CardContent>
      </Card>

      {/* 银行存款余额 */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">
            银行存款
          </CardTitle>
          <Building2 className="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">
            {bankBalance ? formatEther(bankBalance as bigint) : '0'}
          </div>
          <p className="text-xs text-muted-foreground">
            您在 TokenBank 的存款
          </p>
        </CardContent>
      </Card>

      {/* 银行总存款 */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">
            银行总存款
          </CardTitle>
          <Coins className="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">
            {totalDeposits ? formatEther(totalDeposits as bigint) : '0'}
          </div>
          <p className="text-xs text-muted-foreground">
            TokenBank 总锁定量
          </p>
        </CardContent>
      </Card>
      </div>
    </div>
  )
}