import { useState, useEffect } from 'react'
import { useChainId } from 'wagmi'
import { parseUnits, createWalletClient, createPublicClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts' // 修正导入路径
import { sepolia } from 'viem/chains'
import { Send, AlertCircle, CheckCircle, Copy, X, Zap, Shield, Rocket, Target } from 'lucide-react'
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
  const [isSigning, setIsSigning] = useState(false)
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
      setIsSigning(true)
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
      setIsSigning(false)
      setIsLoading(false)
    }
  }

  return (
    <Card className="glass-effect-strong hover-lift border-border/30 shadow-glow-pink">
      <CardHeader className="pb-6">
        <CardTitle className="flex items-center gap-3 text-xl">
          <div className="relative">
            <div className="absolute inset-0 animate-pulse-glow rounded-full"></div>
            <Send className="h-6 w-6 text-gradient relative z-10" />
            <Rocket className="h-3 w-3 text-trae-pink absolute -top-1 -right-1 animate-bounce-gentle" />
          </div>
          <span className="text-gradient">量子传输引擎</span>
        </CardTitle>
        <CardDescription className="text-foreground/70 text-base">
          {wallet?.privateKey ? (
            <div className="flex items-center gap-2">
              <Shield className="h-4 w-4 text-trae-cyan" />
              <span>量子级本地签名模式已启用 - 私钥安全保护</span>
            </div>
          ) : (
            "构建、签名并发送ERC20代币转账交易"
          )}
        </CardDescription>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* 转账参数 */}
          <div className="glass-effect p-5 rounded-xl border border-border/20">
            <h3 className="font-semibold text-lg flex items-center gap-2 mb-4">
              <Target className="h-5 w-5 text-trae-purple" />
              传输参数配置
            </h3>
            
            <div className="space-y-4">
              <div className="space-y-2">
                <Label className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-trae-cyan rounded-full animate-pulse-glow"></div>
                  发送地址 (From)
                </Label>
                <Input 
                  placeholder="0x... 发送方钱包地址"
                  value={fromAddress}
                  onChange={(e) => setFromAddress(e.target.value)}
                  className="font-mono text-sm glass-effect border-border/30 bg-card/50"
                />
              </div>
              
              <div className="space-y-2">
                <Label className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-trae-pink rounded-full animate-pulse-glow"></div>
                  接收地址 (To)
                </Label>
                <Input 
                  placeholder="0x... 接收方钱包地址"
                  value={transferTo}
                  onChange={(e) => setTransferTo(e.target.value)}
                  className="font-mono text-sm glass-effect border-border/30 bg-card/50"
                />
              </div>
              
              <div className="space-y-2">
                <Label className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-trae-purple rounded-full animate-pulse-glow"></div>
                  传输数量
                </Label>
                <Input 
                  placeholder="1.0"
                  value={transferAmount}
                  onChange={(e) => setTransferAmount(e.target.value)}
                  type="number"
                  step="0.000001"
                  className="glass-effect border-border/30 bg-card/50"
                />
              </div>
            
              <div className="space-y-2">
                <div className="flex justify-between items-center">
                  <Label className="flex items-center gap-2">
                    <div className="w-2 h-2 bg-trae-orange rounded-full animate-pulse-glow"></div>
                    ERC20代币合约
                  </Label>
                  <Button 
                    size="sm" 
                    variant="ghost" 
                    onClick={fetchTokenDecimals}
                    disabled={!transferTokenAddress}
                    className="glass-effect hover-glow text-xs"
                  >
                    扫描代币信息
                  </Button>
                </div>
                <Input 
                  placeholder="0x... 代币合约地址"
                  value={transferTokenAddress}
                  onChange={(e) => setTransferTokenAddress(e.target.value)}
                  className="font-mono text-sm glass-effect border-border/30 bg-card/50"
                />
                {tokenDecimals && (
                  <div className="flex items-center gap-2 p-2 rounded-lg bg-trae-purple/10 border border-trae-purple/20">
                    <Zap className="h-3 w-3 text-trae-purple" />
                    <p className="text-xs text-trae-purple font-medium">
                      代币精度: {tokenDecimals} 位小数
                    </p>
                  </div>
                )}
              </div>
            </div>
          </div>
          
          {/* Gas参数 */}
          <div className="glass-effect p-5 rounded-xl border border-border/20">
            <h3 className="font-semibold text-lg flex items-center gap-2 mb-4">
              <Zap className="h-5 w-5 text-trae-cyan" />
              量子燃料配置 (EIP-1559)
            </h3>
            
            <div className="space-y-4">
              <div className="space-y-2">
                <Label className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-trae-cyan rounded-full animate-pulse-glow"></div>
                  Gas 限制
                </Label>
                <Input 
                  value={gasLimit}
                  onChange={(e) => setGasLimit(e.target.value)}
                  type="number"
                  className="glass-effect border-border/30 bg-card/50"
                />
                <div className="flex items-center gap-2 p-2 rounded-lg bg-trae-cyan/10 border border-trae-cyan/20">
                  <Zap className="h-3 w-3 text-trae-cyan" />
                  <p className="text-xs text-trae-cyan font-medium">
                    ERC20传输推荐: 60,000 Gas
                  </p>
                </div>
              </div>
              
              <div className="space-y-2">
                <Label className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-trae-pink rounded-full animate-pulse-glow"></div>
                  最大燃料费 (Gwei)
                </Label>
                <Input 
                  value={maxFeePerGas}
                  onChange={(e) => setMaxFeePerGas(e.target.value)}
                  type="number"
                  step="0.1"
                  className="glass-effect border-border/30 bg-card/50"
                />
              </div>
              
              <div className="space-y-2">
                <Label className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-trae-purple rounded-full animate-pulse-glow"></div>
                  优先级费用 (Gwei)
                </Label>
                <Input 
                  value={maxPriorityFeePerGas}
                  onChange={(e) => setMaxPriorityFeePerGas(e.target.value)}
                  type="number"
                  step="0.1"
                  className="glass-effect border-border/30 bg-card/50"
                />
              </div>
            </div>
          </div>
        </div>
        
        <div className="mt-6 space-y-4">
          <Button 
            onClick={sendERC20Transfer}
            disabled={!wallet?.privateKey || isLoading}
            className="w-full gradient-trae hover-glow text-white font-semibold py-4 text-lg shadow-glow"
            size="lg"
          >
            {isSigning ? (
              <div className="flex items-center gap-3">
                <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                <Shield className="h-5 w-5 animate-pulse-glow" />
                量子签名中...
              </div>
            ) : isLoading ? (
              <div className="flex items-center gap-3">
                <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                <Rocket className="h-5 w-5 animate-pulse-glow" />
                传输发射中...
              </div>
            ) : (
              <>
                <Shield className="h-5 w-5 mr-3" />
                量子签名并发射传输
                <Rocket className="h-5 w-5 ml-3" />
              </>
            )}
          </Button>
          
          {!wallet?.privateKey && (
            <div className="glass-effect p-4 rounded-xl border border-destructive/20 bg-destructive/5">
              <div className="flex items-center gap-3">
                <AlertCircle className="h-5 w-5 text-destructive" />
                <div>
                  <p className="text-sm font-medium text-destructive">量子签名器未激活</p>
                  <p className="text-xs text-destructive/70">请生成或导入包含私钥的量子钱包</p>
                </div>
              </div>
            </div>
          )}
          
          {chainId !== sepolia.id && (
            <div className="glass-effect p-4 rounded-xl border border-yellow-500/20 bg-yellow-500/5">
              <div className="flex items-center gap-3">
                <AlertCircle className="h-5 w-5 text-yellow-600" />
                <div>
                  <p className="text-sm font-medium text-yellow-600">网络维度错误</p>
                  <p className="text-xs text-yellow-600/70">请切换到Sepolia测试网维度</p>
                </div>
              </div>
            </div>
          )}
          
          {/* 成功消息 */}
          {transactionHash && (
            <div className="glass-effect p-5 rounded-xl border border-trae-cyan/30 bg-gradient-to-r from-trae-cyan/10 to-trae-purple/10 animate-slide-up">
              <div className="flex items-center gap-3 mb-4">
                <div className="p-2 rounded-lg bg-trae-cyan/20">
                  <CheckCircle className="h-5 w-5 text-trae-cyan" />
                </div>
                <div>
                  <span className="font-semibold text-lg text-gradient">量子传输成功</span>
                  <p className="text-xs text-foreground/60">交易已发射至区块链网络</p>
                </div>
              </div>
              <div className="space-y-3">
                <div>
                  <p className="text-sm font-medium mb-2 flex items-center gap-2">
                    <Zap className="h-4 w-4 text-trae-purple" />
                    传输哈希标识:
                  </p>
                  <div className="flex items-center gap-3">
                    <code className="glass-effect px-3 py-2 rounded-lg text-xs font-mono bg-card/50 border border-border/30 break-all flex-1">
                      {transactionHash}
                    </code>
                    <Button 
                      size="sm" 
                      variant="outline"
                      className="glass-effect hover-glow border-border/30"
                      onClick={() => copyToClipboard(transactionHash, '交易哈希')}
                    >
                      <Copy className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
                <div className="flex items-center gap-2 p-3 rounded-lg bg-trae-cyan/10 border border-trae-cyan/20">
                  <Rocket className="h-4 w-4 text-trae-cyan" />
                  <p className="text-sm text-trae-cyan font-medium">
                    在 <a href={`https://sepolia.etherscan.io/tx/${transactionHash}`} target="_blank" rel="noopener noreferrer" className="underline hover:text-trae-purple transition-colors">Sepolia 区块链浏览器</a> 中追踪传输状态
                  </p>
                </div>
              </div>
            </div>
          )}
          
          {/* 失败消息（可复制） */}
          {errorMessage && (
            <div className="glass-effect p-5 rounded-xl border border-destructive/30 bg-gradient-to-r from-destructive/10 to-red-500/10 animate-slide-up">
              <div className="flex items-center justify-between gap-3 mb-4">
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-lg bg-destructive/20">
                    <AlertCircle className="h-5 w-5 text-destructive" />
                  </div>
                  <div>
                    <span className="font-semibold text-lg text-destructive">量子传输失败</span>
                    <p className="text-xs text-destructive/70">传输过程中遇到异常</p>
                  </div>
                </div>
                <Button 
                  size="sm" 
                  variant="ghost" 
                  onClick={() => setErrorMessage('')}
                  className="glass-effect hover-glow h-8 w-8 p-0"
                >
                  <X className="h-4 w-4" />
                </Button>
              </div>
              <div className="space-y-3">
                <div>
                  <p className="text-sm font-medium mb-2 flex items-center gap-2">
                    <Zap className="h-4 w-4 text-destructive" />
                    异常诊断信息:
                  </p>
                  <div className="flex items-center gap-3">
                    <code className="glass-effect px-3 py-2 rounded-lg text-xs font-mono bg-card/50 border border-destructive/30 break-all flex-1">
                      {errorMessage}
                    </code>
                    <Button 
                      size="sm" 
                      variant="outline"
                      className="glass-effect hover-glow border-destructive/30"
                      onClick={() => copyToClipboard(errorMessage, '错误信息')}
                    >
                      <Copy className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
                <div className="flex items-center gap-2 p-3 rounded-lg bg-destructive/10 border border-destructive/20">
                  <Shield className="h-4 w-4 text-destructive" />
                  <p className="text-sm text-destructive font-medium">
                    常见原因：余额不足、Gas配置错误、网络连接异常或合约执行失败
                  </p>
                </div>
              </div>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  )
}
