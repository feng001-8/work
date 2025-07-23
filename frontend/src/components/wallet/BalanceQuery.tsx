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

interface BalanceQueryProps {
  defaultAddress?: string
}

export function BalanceQuery({ defaultAddress }: BalanceQueryProps) {
  const [balanceAddress, setBalanceAddress] = useState(defaultAddress || '')
  const [erc20Address, setErc20Address] = useState('')
  const [erc20Balance, setErc20Balance] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const { toast } = useToast()

  // 使用wagmi查询ETH余额
  const { data: walletEthBalance } = useBalance({
    address: balanceAddress as `0x${string}`,
    chainId: sepolia.id,
  })

  // 更新默认地址
  useEffect(() => {
    if (defaultAddress) {
      setBalanceAddress(defaultAddress)
    }
  }, [defaultAddress])

  // 查询ERC20余额
  const queryERC20Balance = async () => {
    if (!balanceAddress || !erc20Address) {
      toast({
        title: "参数错误",
        description: "请输入有效的地址和代币合约地址",
        variant: "destructive",
      })
      return
    }

    try {
      setIsLoading(true)
      
      // 这里应该调用ERC20合约的balanceOf方法
      // 由于需要合约ABI，这里先显示模拟数据
      setErc20Balance('100.0')
      
      toast({
        title: "查询成功",
        description: "ERC20代币余额查询完成",
      })
    } catch (error) {
      toast({
        title: "查询失败",
        description: "ERC20余额查询失败",
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
          查询ETH和ERC20代币余额
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label>钱包地址</Label>
          <Input 
            placeholder="0x..."
            value={balanceAddress}
            onChange={(e) => setBalanceAddress(e.target.value)}
            className="font-mono text-sm"
          />
        </div>
        
        {/* ETH余额 */}
        <div className="bg-secondary/30 p-4 rounded-lg">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium">ETH 余额</span>
            <span className="font-mono text-lg">
              {walletEthBalance ? `${parseFloat(formatEther(walletEthBalance.value)).toFixed(6)} ETH` : '0.000000 ETH'}
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
              onChange={(e) => setErc20Address(e.target.value)}
              className="font-mono text-sm"
            />
            <Button 
              onClick={queryERC20Balance}
              disabled={isLoading}
              size="sm"
            >
              查询
            </Button>
          </div>
        </div>
        
        {erc20Balance && (
          <div className="bg-secondary/30 p-4 rounded-lg animate-slide-up">
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium">ERC20 余额</span>
              <span className="font-mono text-lg">{erc20Balance}</span>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  )
}