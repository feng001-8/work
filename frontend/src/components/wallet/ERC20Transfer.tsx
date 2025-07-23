import { useState, useEffect } from 'react'
import { useChainId } from 'wagmi'
import { parseUnits, createWalletClient, createPublicClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts' // 修正导入路径
import { sepolia } from 'viem/chains'
import { Send, AlertCircle, CheckCircle, Copy, X } from 'lucide-react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card'
import { Button } from '../ui/button'
import { Input } from '../ui/input'
import { Label } from '../ui/label'
import { useToast } from '../ui/use-toast'
// 只导入类型，避免冲突
import type { GeneratedWallet } from './PrivateKeyGenerator'
// 导入合约ABI和地址配置
import { ERC20_ABI, CONTRACTS } from '../../lib/contracts' 

interface ERC20TransferProps {
  wallet?: GeneratedWallet | null
}

export function ERC20Transfer({ wallet }: ERC20TransferProps) {
  const chainId = useChainId()
  const { toast } = useToast()
  
  // 状态管理
  const [fromAddress, setFromAddress] = useState('')
  const [transferTo, setTransferTo] = useState('')
  const [transferAmount, setTransferAmount] = useState('')
  const [transferTokenAddress, setTransferTokenAddress] = useState('')
  const [gasLimit, setGasLimit] = useState('60000')
  const [maxFeePerGas, setMaxFeePerGas] = useState('20')
  const [maxPriorityFeePerGas, setMaxPriorityFeePerGas] = useState('2')
  const [transactionHash, setTransactionHash] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [tokenDecimals, setTokenDecimals] = useState(18)
  const [errorMessage, setErrorMessage] = useState('')

  // 自动填充发送地址（从钱包）
  useEffect(() => {
    if (wallet?.account) {
      setFromAddress(wallet.account)
    }
  }, [wallet])

  // 自动设置代币地址（根据网络）
  useEffect(() => {
    if (chainId === sepolia.id) {
      setTransferTokenAddress(CONTRACTS.SEPOLIA.ERC20_TOKEN)
    } else if (chainId === 31337) {
      setTransferTokenAddress(CONTRACTS.LOCALHOST.ERC20_TOKEN)
    } else {
      setTransferTokenAddress('')
    }
  }, [chainId])

  // 复制功能
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

  // 获取代币小数位
  const fetchTokenDecimals = async () => {
    if (!transferTokenAddress) return

    try {
      const publicClient = createPublicClient({
        chain: sepolia,
        transport: http('https://sepolia.drpc.org'),
      })

      const decimals = await publicClient.readContract({
        address: transferTokenAddress as `0x${string}`,
        abi: ERC20_ABI,
        functionName: 'decimals',
      })

      setTokenDecimals(decimals)
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : "获取代币信息失败"
      setErrorMessage(errMsg)
      toast({
        title: "获取代币信息失败",
        description: errMsg,
        variant: "destructive",
      })
    }
  }

  // 发送交易（核心优化：本地签名）
  const sendERC20Transfer = async () => {
    // 重置状态
    setTransactionHash('')
    setErrorMessage('')

    // 输入验证
    if (!wallet?.privateKey) {
      const errMsg = "钱包私钥缺失，无法签名交易"
      setErrorMessage(errMsg)
      toast({ title: "签名失败", description: errMsg, variant: "destructive" })
      return
    }

    if (!fromAddress || !transferTo || !transferAmount || !transferTokenAddress) {
      const errMsg = "请填写完整的转账信息"
      setErrorMessage(errMsg)
      toast({ title: "参数错误", description: errMsg, variant: "destructive" })
      return
    }

    // 地址格式验证
    if (!/^0x[a-fA-F0-9]{40}$/.test(fromAddress)) {
      const errMsg = "发送地址格式错误（需为42位0x开头的十六进制地址）"
      setErrorMessage(errMsg)
      toast({ title: "地址错误", description: errMsg, variant: "destructive" })
      return
    }

    if (!/^0x[a-fA-F0-9]{40}$/.test(transferTo)) {
      const errMsg = "接收地址格式错误（需为42位0x开头的十六进制地址）"
      setErrorMessage(errMsg)
      toast({ title: "地址错误", description: errMsg, variant: "destructive" })
      return
    }

    if (!/^0x[a-fA-F0-9]{40}$/.test(transferTokenAddress)) {
      const errMsg = "代币地址格式错误（需为42位0x开头的十六进制地址）"
      setErrorMessage(errMsg)
      toast({ title: "地址错误", description: errMsg, variant: "destructive" })
      return
    }

    // 金额验证
    if (isNaN(Number(transferAmount)) || Number(transferAmount) <= 0) {
      const errMsg = "转账金额必须为大于0的数字"
      setErrorMessage(errMsg)
      toast({ title: "金额错误", description: errMsg, variant: "destructive" })
      return
    }

    try {
      setIsLoading(true)
      
      // 使用私钥创建本地账户（用于本地签名）
      const account = privateKeyToAccount(wallet.privateKey as `0x${string}`)
      
      // 创建钱包客户端（配置本地签名账户）
      const walletClient = createWalletClient({
        account,
        chain: sepolia,
        transport: http('https://sepolia.drpc.org'),
      })

      // 解析金额
      const amount = parseUnits(transferAmount, tokenDecimals)
      
      // 发送交易（显式指定account参数以解决类型问题）
      const hash = await walletClient.writeContract({
        address: transferTokenAddress as `0x${string}`,
        abi: ERC20_ABI,
        functionName: 'transfer',
        args: [transferTo as `0x${string}`, amount],
        account: account.address, // 显式指定账户地址
        gas: BigInt(gasLimit),
        maxFeePerGas: parseUnits(maxFeePerGas, 9),
        maxPriorityFeePerGas: parseUnits(maxPriorityFeePerGas, 9),
      })

      setTransactionHash(hash)
      toast({
        title: "交易发送成功",
        description: `交易哈希: ${hash}`,
      })
    } catch (error: any) {
      // 捕获详细错误信息
      const errMsg = error.message || "交易发送失败"
      setErrorMessage(errMsg)
      toast({
        title: "交易失败",
        description: errMsg,
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
          构建、签名并发送ERC20代币转账交易（本地签名模式）
        </CardDescription>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* 转账参数 */}
          <div className="space-y-4">
            <h3 className="font-semibold text-lg">转账参数</h3>
            
            <div className="space-y-2">
              <Label>发送地址 (From)</Label>
              <Input 
                placeholder="0x..."
                value={fromAddress}
                onChange={(e) => setFromAddress(e.target.value)}
                className="font-mono text-sm"
              />
            </div>
            
            <div className="space-y-2">
              <Label>接收地址 (To)</Label>
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
              <div className="flex justify-between">
                <Label>ERC20代币地址</Label>
                <Button 
                  size="sm" 
                  variant="ghost" 
                  onClick={fetchTokenDecimals}
                  disabled={!transferTokenAddress}
                >
                  加载代币信息
                </Button>
              </div>
              <Input 
                placeholder="0x..."
                value={transferTokenAddress}
                onChange={(e) => setTransferTokenAddress(e.target.value)}
                className="font-mono text-sm"
              />
              {tokenDecimals && (
                <p className="text-xs text-muted-foreground">
                  代币小数位: {tokenDecimals}
                </p>
              )}
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
              <p className="text-xs text-muted-foreground">
                ERC20转账建议值: 60000
              </p>
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
            disabled={!wallet?.privateKey || isLoading}
            className="w-full"
            size="lg"
          >
            {isLoading ? (
              <div className="flex items-center gap-2">
                <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                签名发送中...
              </div>
            ) : (
              <>
                <Send className="h-4 w-4 mr-2" />
                签名并发送交易
              </>
            )}
          </Button>
          
          {!wallet?.privateKey && (
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <AlertCircle className="h-4 w-4" />
              请导入包含私钥的钱包以完成签名
            </div>
          )}
          
          {chainId !== sepolia.id && (
            <div className="flex items-center gap-2 text-sm text-yellow-600">
              <AlertCircle className="h-4 w-4" />
              请切换到Sepolia测试网
            </div>
          )}
          
          {/* 成功消息 */}
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
                  可在 <a href={`https://sepolia.etherscan.io/tx/${transactionHash}`} target="_blank" rel="noopener noreferrer" className="underline">Sepolia Etherscan</a> 上查看交易状态
                </p>
              </div>
            </div>
          )}
          
          {/* 失败消息（可复制） */}
          {errorMessage && (
            <div className="bg-red-50 border border-red-200 p-4 rounded-lg animate-slide-up">
              <div className="flex items-center justify-between gap-2 mb-2">
                <div className="flex items-center gap-2">
                  <AlertCircle className="h-4 w-4 text-red-600" />
                  <span className="font-semibold text-red-800">交易失败</span>
                </div>
                <Button 
                  size="sm" 
                  variant="ghost" 
                  onClick={() => setErrorMessage('')}
                  className="h-6 w-6 p-0"
                >
                  <X className="h-3 w-3" />
                </Button>
              </div>
              <div className="space-y-2">
                <p className="text-sm text-red-700">错误信息:</p>
                <div className="flex items-center gap-2">
                  <code className="bg-red-100 px-2 py-1 rounded text-xs font-mono text-red-800 break-all max-w-full">
                    {errorMessage}
                  </code>
                  <Button 
                    size="sm" 
                    variant="outline"
                    onClick={() => copyToClipboard(errorMessage, '错误信息')}
                  >
                    <Copy className="h-3 w-3" />
                  </Button>
                </div>
                <p className="text-xs text-red-600">
                  提示：常见原因包括余额不足、Gas不足或节点连接问题
                </p>
              </div>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  )
}
