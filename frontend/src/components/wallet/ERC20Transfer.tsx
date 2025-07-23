import { useState } from 'react'
import { useChainId } from 'wagmi'
import { parseUnits, createWalletClient, http } from 'viem'
import { sepolia } from 'viem/chains'
import { Send, AlertCircle, CheckCircle, Copy } from 'lucide-react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card'
import { Button } from '../ui/button'
import { Input } from '../ui/input'
import { Label } from '../ui/label'
import { useToast } from '../ui/use-toast'
import { GeneratedWallet } from './PrivateKeyGenerator'

interface ERC20TransferProps {
  wallet?: GeneratedWallet | null
}

export function ERC20Transfer({ wallet }: ERC20TransferProps) {
  const chainId = useChainId()
  const { toast } = useToast()
  
  // 转账状态
  const [transferTo, setTransferTo] = useState('')
  const [transferAmount, setTransferAmount] = useState('')
  const [transferTokenAddress, setTransferTokenAddress] = useState('')
  const [gasLimit, setGasLimit] = useState('21000')
  const [maxFeePerGas, setMaxFeePerGas] = useState('20')
  const [maxPriorityFeePerGas, setMaxPriorityFeePerGas] = useState('2')
  const [transactionHash, setTransactionHash] = useState('')
  const [isLoading, setIsLoading] = useState(false)

  // 复制到剪贴板
  const copyToClipboard = async (text: string, label: string) => {
    try {
      await navigator.clipboard.writeText(text)
      toast({
        title: "复制成功",
        description: `${label}已复制到剪贴板`,
      })
    } catch (error) {
      toast({
        title: "复制失败",
        description: "无法复制到剪贴板",
        variant: "destructive",
      })
    }
  }

  // 构建并发送ERC20转账交易
  const sendERC20Transfer = async () => {
    if (!wallet || !transferTo || !transferAmount || !transferTokenAddress) {
      toast({
        title: "参数错误",
        description: "请填写完整的转账信息",
        variant: "destructive",
      })
      return
    }

    if (chainId !== sepolia.id) {
      toast({
        title: "网络错误",
        description: "请切换到Sepolia测试网络",
        variant: "destructive",
      })
      return
    }

    try {
      setIsLoading(true)
      
      // 创建钱包客户端
      const walletClient = createWalletClient({
        account: wallet.account,
        chain: sepolia,
        transport: http()
      })

      // ERC20 transfer函数的ABI
      const transferAbi = [
        {
          name: 'transfer',
          type: 'function',
          inputs: [
            { name: 'to', type: 'address' },
            { name: 'amount', type: 'uint256' }
          ],
          outputs: [{ name: '', type: 'bool' }],
          stateMutability: 'nonpayable'
        }
      ] as const

      // 构建交易数据
      const amount = parseUnits(transferAmount, 18) // 假设18位小数
      
      // 发送交易
      const hash = await walletClient.writeContract({
        address: transferTokenAddress as `0x${string}`,
        abi: transferAbi,
        functionName: 'transfer',
        args: [transferTo as `0x${string}`, amount],
        account: wallet.account,
        gas: BigInt(gasLimit),
        maxFeePerGas: parseUnits(maxFeePerGas, 9), // Gwei to Wei
        maxPriorityFeePerGas: parseUnits(maxPriorityFeePerGas, 9),
      })

      setTransactionHash(hash)
      
      toast({
        title: "交易发送成功",
        description: `交易哈希: ${hash}`,
      })
    } catch (error: any) {
      toast({
        title: "交易失败",
        description: error.message || "交易发送失败",
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
          <Send className="h-5 w-5 text-primary" />
          ERC20 转账 (EIP-1559)
        </CardTitle>
        <CardDescription>
          构建、签名并发送ERC20代币转账交易到Sepolia网络
        </CardDescription>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* 转账参数 */}
          <div className="space-y-4">
            <h3 className="font-semibold text-lg">转账参数</h3>
            
            <div className="space-y-2">
              <Label>接收地址</Label>
              <Input 
                placeholder="0x..."
                value={transferTo}
                onChange={(e) => setTransferTo(e.target.value)}
                className="font-mono text-sm"
              />
            </div>
            
            <div className="space-y-2">
              <Label>转账金额</Label>
              <Input 
                placeholder="1.0"
                value={transferAmount}
                onChange={(e) => setTransferAmount(e.target.value)}
                type="number"
                step="0.000001"
              />
            </div>
            
            <div className="space-y-2">
              <Label>ERC20代币地址</Label>
              <Input 
                placeholder="0x..."
                value={transferTokenAddress}
                onChange={(e) => setTransferTokenAddress(e.target.value)}
                className="font-mono text-sm"
              />
            </div>
          </div>
          
          {/* Gas参数 */}
          <div className="space-y-4">
            <h3 className="font-semibold text-lg">Gas 参数 (EIP-1559)</h3>
            
            <div className="space-y-2">
              <Label>Gas Limit</Label>
              <Input 
                value={gasLimit}
                onChange={(e) => setGasLimit(e.target.value)}
                type="number"
              />
            </div>
            
            <div className="space-y-2">
              <Label>Max Fee Per Gas (Gwei)</Label>
              <Input 
                value={maxFeePerGas}
                onChange={(e) => setMaxFeePerGas(e.target.value)}
                type="number"
                step="0.1"
              />
            </div>
            
            <div className="space-y-2">
              <Label>Max Priority Fee Per Gas (Gwei)</Label>
              <Input 
                value={maxPriorityFeePerGas}
                onChange={(e) => setMaxPriorityFeePerGas(e.target.value)}
                type="number"
                step="0.1"
              />
            </div>
          </div>
        </div>
        
        <div className="mt-6 space-y-4">
          <Button 
            onClick={sendERC20Transfer}
            disabled={!wallet || isLoading || chainId !== sepolia.id}
            className="w-full"
            size="lg"
          >
            {isLoading ? (
              <div className="flex items-center gap-2">
                <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                发送中...
              </div>
            ) : (
              <>
                <Send className="h-4 w-4 mr-2" />
                签名并发送交易
              </>
            )}
          </Button>
          
          {!wallet && (
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <AlertCircle className="h-4 w-4" />
              请先生成钱包私钥
            </div>
          )}
          
          {chainId !== sepolia.id && (
            <div className="flex items-center gap-2 text-sm text-yellow-600">
              <AlertCircle className="h-4 w-4" />
              请切换到Sepolia测试网络
            </div>
          )}
          
          {transactionHash && (
            <div className="bg-green-50 border border-green-200 p-4 rounded-lg animate-slide-up">
              <div className="flex items-center gap-2 mb-2">
                <CheckCircle className="h-4 w-4 text-green-600" />
                <span className="font-semibold text-green-800">交易发送成功</span>
              </div>
              <div className="space-y-2">
                <p className="text-sm text-green-700">交易哈希:</p>
                <div className="flex items-center gap-2">
                  <code className="bg-green-100 px-2 py-1 rounded text-xs font-mono text-green-800 break-all">
                    {transactionHash}
                  </code>
                  <Button 
                    size="sm" 
                    variant="outline"
                    onClick={() => copyToClipboard(transactionHash, '交易哈希')}
                  >
                    <Copy className="h-3 w-3" />
                  </Button>
                </div>
                <p className="text-xs text-green-600">
                  可在 Sepolia Etherscan 上查看交易状态
                </p>
              </div>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  )
}