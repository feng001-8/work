import { useState, useEffect } from 'react'
import { useBalance } from 'wagmi'
import { sepolia } from 'viem/chains'
import { Wallet, Search, Coins, TrendingUp, Zap, Activity } from 'lucide-react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card'
import { Button } from '../ui/button'
import { Input } from '../ui/input'
import { Label } from '../ui/label'
import { useToast } from '../ui/use-toast'
import { formatEther } from '../../lib/utils'
import { createPublicClient, http, isAddress, formatUnits } from 'viem'
import { ERC20_ABI, CONTRACTS } from '../../lib/contracts'

interface BalanceQueryProps {
  defaultAddress?: string
}

export function BalanceQuery({ defaultAddress }: BalanceQueryProps) {
  const [balanceAddress, setBalanceAddress] = useState(defaultAddress || '')
  // 修正：显式指定状态类型为 string
  const [erc20Address, setErc20Address] = useState<string>(CONTRACTS.SEPOLIA.ERC20_TOKEN)
  const [erc20Balance, setErc20Balance] = useState('')
  const [tokenSymbol, setTokenSymbol] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const { toast } = useToast()

  // 查询ETH余额
  // 修正：使用 query.enabled 替代 watch
  const { data: walletEthBalance, isFetching: isEthLoading } = useBalance({
    address: balanceAddress as `0x${string}`,
    chainId: sepolia.id,
    query: {
      enabled: !!balanceAddress && isAddress(balanceAddress),
    },
  })

  // 更新默认地址
  useEffect(() => {
    if (defaultAddress && isAddress(defaultAddress)) {
      setBalanceAddress(defaultAddress)
    }
  }, [defaultAddress])

  // 验证地址格式
  const validateAddresses = () => {
    if (!balanceAddress || !isAddress(balanceAddress)) {
      toast({
        title: "无效地址",
        description: "请输入有效的钱包地址",
        variant: "destructive",
      })
      return false
    }

    if (!erc20Address || !isAddress(erc20Address)) {
      toast({
        title: "无效代币地址",
        description: "请输入有效的ERC20代币合约地址",
        variant: "destructive",
      })
      return false
    }

    return true
  }

  // 查询ERC20代币符号
  const fetchTokenSymbol = async (client: any, address: `0x${string}`) => {
    try {
      const symbol = await client.readContract({
        address,
        abi: ERC20_ABI, // 使用导入的ERC20_ABI
        functionName: 'symbol',
      })
      return symbol
    } catch (error) {
      console.warn('无法获取代币符号，使用默认名称', error)
      return '代币'
    }
  }

  // 查询ERC20余额
  const queryERC20Balance = async () => {
    if (!validateAddresses()) return

    try {
      setIsLoading(true)
      setErc20Balance('')
      setTokenSymbol('')
      
      const publicClient = createPublicClient({
        chain: sepolia,
        transport: http()
      })

      // 获取代币符号
      const symbol = await fetchTokenSymbol(publicClient, erc20Address as `0x${string}`)
      setTokenSymbol(symbol)

      // 获取余额
      const balance = await publicClient.readContract({
        address: erc20Address as `0x${string}`,
        abi: ERC20_ABI, // 使用导入的ERC20_ABI
        functionName: 'balanceOf',
        args: [balanceAddress as `0x${string}`]
      })

      // 获取代币小数位
      let decimals = 18
      try {
        decimals = await publicClient.readContract({
          address: erc20Address as `0x${string}`,
          abi: ERC20_ABI, // 使用导入的ERC20_ABI
          functionName: 'decimals',
        })
      } catch (error) {
        console.warn('无法获取代币小数位，使用默认18位', error)
      }

      const formattedBalance = formatUnits(balance, decimals)
      const displayBalance = parseFloat(formattedBalance).toFixed(6)
      setErc20Balance(`${displayBalance} ${symbol}`)
      
      toast({
        title: "查询成功",
        description: `已获取 ${symbol} 余额`,
      })
    } catch (error) {
      console.error('ERC20余额查询失败:', error)
      toast({
        title: "查询失败",
        description: "请检查代币地址是否正确或网络连接",
        variant: "destructive",
      })
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <Card className="glass-effect-strong hover-lift border-border/30 shadow-glow-cyan">
      <CardHeader className="pb-6">
        <CardTitle className="flex items-center gap-3 text-xl">
          <div className="relative">
            <div className="absolute inset-0 animate-pulse-glow rounded-full"></div>
            <Wallet className="h-6 w-6 text-gradient relative z-10" />
            <Activity className="h-3 w-3 text-trae-cyan absolute -top-1 -right-1 animate-bounce-gentle" />
          </div>
          <span className="text-gradient">量子余额扫描器</span>
        </CardTitle>
        <CardDescription className="text-foreground/70 text-base">
          实时扫描Sepolia测试网的ETH和ERC20代币余额
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-6">
        <div className="glass-effect p-4 rounded-xl border border-border/20">
          <div className="space-y-3">
            <Label className="text-base font-semibold flex items-center gap-2">
              <div className="w-2 h-2 bg-trae-purple rounded-full animate-pulse-glow"></div>
              目标钱包地址
            </Label>
            <Input 
              placeholder="0x... 输入要查询的钱包地址"
              value={balanceAddress}
              onChange={(e) => setBalanceAddress(e.target.value.trim())}
              className="font-mono text-sm glass-effect border-border/30 bg-card/50"
              maxLength={42}
            />
          </div>
        </div>
        
        {/* ETH余额 */}
        <div className="glass-effect p-5 rounded-xl border border-border/20 bg-gradient-to-r from-trae-purple/10 to-trae-cyan/10">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-trae-purple/20">
                <Zap className="h-5 w-5 text-trae-purple" />
              </div>
              <div>
                <span className="text-base font-semibold">ETH 余额</span>
                <p className="text-xs text-foreground/60">以太坊主币</p>
              </div>
            </div>
            <div className="text-right">
              <span className="font-mono text-xl font-bold text-gradient">
                {isEthLoading ? (
                  <span className="animate-pulse">扫描中...</span>
                ) : 
                 walletEthBalance ? `${parseFloat(formatEther(walletEthBalance.value)).toFixed(6)}` : 
                 '0.000000'}
              </span>
              <p className="text-sm text-foreground/60">ETH</p>
            </div>
          </div>
        </div>
        
        {/* ERC20余额查询 */}
        <div className="glass-effect p-4 rounded-xl border border-border/20">
          <div className="space-y-3">
            <Label className="text-base font-semibold flex items-center gap-2">
              <div className="w-2 h-2 bg-trae-pink rounded-full animate-pulse-glow"></div>
              ERC20代币合约地址
            </Label>
            <div className="flex gap-3">
              <Input 
                placeholder="0x... 输入代币合约地址"
                value={erc20Address}
                onChange={(e) => setErc20Address(e.target.value.trim())}
                className="font-mono text-sm glass-effect border-border/30 bg-card/50"
                maxLength={42}
              />
              <Button 
                onClick={queryERC20Balance}
                disabled={isLoading || isEthLoading}
                className="gradient-trae hover-glow text-white font-semibold px-6"
                size="sm"
              >
                <Search className="h-4 w-4 mr-2" />
                {isLoading ? '扫描中...' : '量子扫描'}
              </Button>
            </div>
          </div>
        </div>
        
        {erc20Balance && (
          <div className="glass-effect p-5 rounded-xl border border-border/20 bg-gradient-to-r from-trae-pink/10 to-trae-purple/10 animate-slide-up">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-trae-pink/20">
                  <Coins className="h-5 w-5 text-trae-pink" />
                </div>
                <div>
                  <span className="text-base font-semibold">{tokenSymbol} 余额</span>
                  <p className="text-xs text-foreground/60">ERC20代币</p>
                </div>
              </div>
              <div className="text-right">
                <span className="font-mono text-xl font-bold text-gradient">
                  {erc20Balance.split(' ')[0]}
                </span>
                <p className="text-sm text-foreground/60">{tokenSymbol}</p>
              </div>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  )
}