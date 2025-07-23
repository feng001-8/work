import { useState, useEffect } from 'react'
import { useBalance } from 'wagmi'
import { sepolia } from 'viem/chains'
import { Wallet } from 'lucide-react'
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
    <Card className="glass-effect hover-lift animate-scale-in">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Wallet className="h-5 w-5 text-primary" />
          查询余额
        </CardTitle>
        <CardDescription>
          查询Sepolia测试网的ETH和ERC20代币余额
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label>钱包地址</Label>
          <Input 
            placeholder="0x..."
            value={balanceAddress}
            onChange={(e) => setBalanceAddress(e.target.value.trim())}
            className="font-mono text-sm"
            maxLength={42}
          />
        </div>
        
        {/* ETH余额 */}
        <div className="bg-secondary/30 p-4 rounded-lg">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium">ETH 余额</span>
            <span className="font-mono text-lg">
              {isEthLoading ? '加载中...' : 
               walletEthBalance ? `${parseFloat(formatEther(walletEthBalance.value)).toFixed(6)} ETH` : 
               '0.000000 ETH'}
            </span>
          </div>
        </div>
        
        {/* ERC20余额查询 */}
        <div className="space-y-2">
          <Label>ERC20代币地址</Label>
          <div className="flex gap-2">
            <Input 
              placeholder="0x..."
              value={erc20Address}
              onChange={(e) => setErc20Address(e.target.value.trim())}
              className="font-mono text-sm"
              maxLength={42}
            />
            <Button 
              onClick={queryERC20Balance}
              disabled={isLoading || isEthLoading}
              size="sm"
            >
              {isLoading ? '查询中...' : '查询'}
            </Button>
          </div>
        </div>
        
        {erc20Balance && (
          <div className="bg-secondary/30 p-4 rounded-lg animate-slide-up">
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium">{tokenSymbol} 余额</span>
              <span className="font-mono text-lg">{erc20Balance}</span>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  )
}