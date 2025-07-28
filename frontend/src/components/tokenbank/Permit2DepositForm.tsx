import React, { useState } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt, useChainId } from 'wagmi'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card'
import { Button } from '../ui/button'
import { Input } from '../ui/input'
import { Label } from '../ui/label'
import { useToast } from '../ui/use-toast'
import { formatEther, parseEther } from '../../lib/utils'
import { TOKEN_BANK_ABI, ERC20_ABI } from '../../lib/contracts'
import { Shield, Loader2, Copy, Eye, EyeOff, AlertCircle, CheckCircle } from 'lucide-react'
import { signTypedData } from '@wagmi/core'
import { config } from '../../lib/wagmi'
import { keccak256, toHex } from 'viem'

interface Permit2DepositFormProps {
  tokenBankAddress: string
  tokenAddress: string
}

interface SignatureDetails {
  signature: string
  r: string
  s: string
  v: number
  domainSeparator: string
  messageHash: string
  typedDataHash: string
  domain: any
  message: any
}

// Permit2 合约地址 (Sepolia)
const PERMIT2_ADDRESS = '0x31c2F6fcFf4F8759b3Bd5Bf0e1084A055615c768'

export function Permit2DepositForm({ tokenBankAddress, tokenAddress }: Permit2DepositFormProps) {
  const [amount, setAmount] = useState('')
  const [deadline, setDeadline] = useState('')
  const [nonce, setNonce] = useState('')
  const [isSigning, setIsSigning] = useState(false)
  const [signatureDetails, setSignatureDetails] = useState<SignatureDetails | null>(null)
  const [showTechnicalDetails, setShowTechnicalDetails] = useState(false)
  const { address } = useAccount()
  const chainId = useChainId()
  const { toast } = useToast()

  // 读取用户代币余额
  const { data: tokenBalance } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  })

  // 读取代币名称
  const { data: tokenName } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'name',
  })

  // 读取用户对Permit2的授权额度
  const { data: permit2Allowance, refetch: refetchPermit2Allowance } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address ? [address, PERMIT2_ADDRESS] : undefined,
    query: {
      enabled: !!address,
    },
  })

  // 写入合约
  const { writeContract, data: writeData, isPending: isWritePending } = useWriteContract()

  // 存储最后一次交易的哈希和交易类型
  const [lastTxHash, setLastTxHash] = useState<`0x${string}` | undefined>()
  const [txType, setTxType] = useState<'approve' | 'deposit' | undefined>()

  // 等待交易确认
  const { isLoading: isTxLoading } = useWaitForTransactionReceipt({
    hash: lastTxHash,
  })

  // 监听writeData变化，设置交易哈希
  React.useEffect(() => {
    if (writeData) {
      setLastTxHash(writeData)
    }
  }, [writeData])

  // 处理交易成功
  React.useEffect(() => {
    if (isTxLoading === false && lastTxHash) {
      if (txType === 'approve') {
        toast({
          title: "授权成功",
          description: "已成功授权 Permit2 合约，现在可以进行存款",
        })
        refetchPermit2Allowance()
      } else if (txType === 'deposit') {
        const currentAmount = amount // 保存当前金额用于显示
        setAmount('')
        setDeadline('')
        setNonce('')
        setSignatureDetails(null)
        toast({
          title: "Permit2 存款成功",
          description: `成功使用 Permit2 存入 ${currentAmount} 代币到 TokenBank`,
        })
      }
      setLastTxHash(undefined)
      setTxType(undefined)
    }
  }, [isTxLoading, lastTxHash, amount, toast, txType, refetchPermit2Allowance])

  // 处理Permit2授权
  const handleApprovePermit2 = async () => {
    if (!address) {
      toast({
        title: "错误",
        description: "请先连接钱包",
        variant: "destructive",
      })
      return
    }

    try {
       await writeContract({
         address: tokenAddress as `0x${string}`,
         abi: ERC20_ABI,
         functionName: 'approve',
         args: [PERMIT2_ADDRESS, parseEther('1000000')], // 授权大额度
       })
       
       setTxType('approve')
       
       toast({
         title: "授权交易已提交",
         description: "正在等待交易确认...",
       })
    } catch (error: any) {
      console.error('Approve error:', error)
      toast({
        title: "授权失败",
        description: error.message || "授权交易失败",
        variant: "destructive",
      })
    }
  }

  const handlePermit2Deposit = async () => {
    if (!amount || parseFloat(amount) <= 0 || !deadline || !nonce || !address || !tokenName) {
      toast({
        title: "参数错误",
        description: "请填写完整的存款信息",
        variant: "destructive",
      })
      return
    }

    const deadlineTimestamp = Math.floor(new Date(deadline).getTime() / 1000)
    const currentTimestamp = Math.floor(Date.now() / 1000)
    
    if (deadlineTimestamp <= currentTimestamp) {
      toast({
        title: "截止时间错误",
        description: "截止时间必须在未来",
        variant: "destructive",
      })
      return
    }

    setIsSigning(true)

    try {
      // Permit2 EIP-712 域
      const domain = {
        name: 'Permit2',
        chainId: chainId,
        verifyingContract: PERMIT2_ADDRESS as `0x${string}`,
      }

      // Permit2 类型定义
      const types = {
        PermitTransferFrom: [
          { name: 'permitted', type: 'TokenPermissions' },
          { name: 'spender', type: 'address' },
          { name: 'nonce', type: 'uint256' },
          { name: 'deadline', type: 'uint256' },
        ],
        TokenPermissions: [
          { name: 'token', type: 'address' },
          { name: 'amount', type: 'uint256' },
        ],
      }

      // 消息内容
      const message = {
        permitted: {
          token: tokenAddress,
          amount: parseEther(amount),
        },
        spender: tokenBankAddress,
        nonce: BigInt(nonce),
        deadline: BigInt(deadlineTimestamp),
      }

      console.log('Signing Permit2 message:', { domain, types, message })

      // 签名
      const signature = await signTypedData(config, {
        domain,
        types,
        primaryType: 'PermitTransferFrom',
        message,
      })

      console.log('Permit2 signature:', signature)

      // 解析签名
      const r = signature.slice(0, 66)
      const s = '0x' + signature.slice(66, 130)
      const v = parseInt(signature.slice(130, 132), 16)

      // 计算域分隔符
      const domainSeparator = keccak256(
        toHex(
          keccak256(
            toHex(
              'EIP712Domain(string name,uint256 chainId,address verifyingContract)'
            )
          ) +
          keccak256(toHex('Permit2')).slice(2) +
          chainId.toString(16).padStart(64, '0') +
          PERMIT2_ADDRESS.slice(2).toLowerCase()
        )
      )

      // 计算消息哈希
      const messageHash = keccak256(
        toHex(
          keccak256(
            toHex(
              'PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)'
            )
          ) +
          keccak256(
            toHex(
              keccak256(
                toHex(
                  'TokenPermissions(address token,uint256 amount)'
                )
              ) +
              tokenAddress.slice(2).toLowerCase().padStart(64, '0') +
              parseEther(amount).toString(16).padStart(64, '0')
            )
          ).slice(2) +
          tokenBankAddress.slice(2).toLowerCase().padStart(64, '0') +
          BigInt(nonce).toString(16).padStart(64, '0') +
          BigInt(deadlineTimestamp).toString(16).padStart(64, '0')
        )
      )

      const typedDataHash = keccak256(
        toHex('\x19\x01' + domainSeparator.slice(2) + messageHash.slice(2))
      )

      setSignatureDetails({
        signature,
        r,
        s,
        v,
        domainSeparator,
        messageHash,
        typedDataHash,
        domain,
        message,
      })

      toast({
        title: "签名成功",
        description: "Permit2 签名已生成，现在可以执行存款",
      })
    } catch (error: any) {
      console.error('Permit2 signing error:', error)
      toast({
        title: "签名失败",
        description: error.message || "用户拒绝签名",
        variant: "destructive",
      })
    } finally {
      setIsSigning(false)
    }
  }

  const handleExecuteDeposit = async () => {
    if (!signatureDetails || !amount || !deadline || !nonce) {
      toast({
        title: "执行失败",
        description: "请先完成签名",
        variant: "destructive",
      })
      return
    }

    try {
      const deadlineTimestamp = Math.floor(new Date(deadline).getTime() / 1000)
      
      // 构造 permit 参数
      const permit = {
        permitted: {
          token: tokenAddress as `0x${string}`,
          amount: parseEther(amount),
        },
        nonce: BigInt(nonce),
        deadline: BigInt(deadlineTimestamp),
      }

      // 构造 transferDetails 参数
      const transferDetails = {
        to: tokenBankAddress as `0x${string}`,
        requestedAmount: parseEther(amount),
      }

      console.log('Executing Permit2 deposit with:', {
        permit,
        transferDetails,
        signature: signatureDetails.signature
      })

      const txHash = await writeContract({
        address: tokenBankAddress as `0x${string}`,
        abi: TOKEN_BANK_ABI,
        functionName: 'depositWithPermit2',
        args: [permit, transferDetails, address as `0x${string}`, signatureDetails.signature as `0x${string}`],
      })

      console.log('Transaction submitted:', txHash)
      
      setTxType('deposit')
      
      toast({
        title: "交易已提交",
        description: "Permit2 存款交易已提交，等待确认...",
      })
    } catch (error: any) {
      console.error('Permit2 deposit error:', error)
      toast({
        title: "执行失败",
        description: error.message || "交易执行失败",
        variant: "destructive",
      })
    }
  }

  const handleMaxClick = () => {
    if (tokenBalance) {
      setAmount(formatEther(tokenBalance as bigint))
    }
  }

  const handleSetDefaultDeadline = () => {
    const now = new Date()
    now.setHours(now.getHours() + 1) // 默认1小时后过期
    setDeadline(now.toISOString().slice(0, 16))
  }

  const handleSetDefaultNonce = () => {
    // 生成符合 Permit2 bitmap nonce 系统的 nonce
    // nonce = wordPos (248 bits) + bitPos (8 bits)
    const wordPos = BigInt(Math.floor(Math.random() * 1000000)) // 随机 wordPos
    const bitPos = BigInt(Math.floor(Math.random() * 256)) // 0-255 的随机 bitPos
    const nonce = (wordPos << 8n) | bitPos
    setNonce(nonce.toString())
  }

  const copyToClipboard = async (text: string, label: string) => {
    try {
      await navigator.clipboard.writeText(text)
      toast({
        title: "复制成功",
        description: `${label} 已复制到剪贴板`,
      })
    } catch (error) {
      toast({
        title: "复制失败",
        description: "无法复制到剪贴板",
        variant: "destructive",
      })
    }
  }

  const isAmountValid = amount && parseFloat(amount) > 0
  const amountBigInt = isAmountValid ? parseEther(amount) : 0n
  const hasEnoughBalance = tokenBalance && isAmountValid && parseEther(amount) <= (tokenBalance as bigint)
  const isDeadlineValid = deadline && new Date(deadline).getTime() > Date.now()
  const isNonceValid = nonce && parseInt(nonce) >= 0
  const hasEnoughPermit2Allowance = permit2Allowance && isAmountValid && amountBigInt <= (permit2Allowance as bigint)
  const canSign = isAmountValid && hasEnoughBalance && isDeadlineValid && isNonceValid && !signatureDetails && hasEnoughPermit2Allowance
  const canExecute = signatureDetails && hasEnoughBalance && hasEnoughPermit2Allowance && !isTxLoading

  if (!address) {
    return (
      <Card className="w-full">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Shield className="h-5 w-5" />
            Permit2 存款
          </CardTitle>
          <CardDescription>请先连接钱包</CardDescription>
        </CardHeader>
      </Card>
    )
  }

  return (
    <Card className="w-full">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Shield className="h-5 w-5" />
          Permit2 签名存款
        </CardTitle>
        <CardDescription>
          使用 Permit2 进行无需预授权的签名存款
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* 存款金额 */}
        <div className="space-y-2">
          <Label htmlFor="permit2-amount">存款金额</Label>
          <div className="flex space-x-2">
            <Input
              id="permit2-amount"
              type="number"
              placeholder="输入存款金额"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="flex-1"
              disabled={!!signatureDetails}
            />
            <Button 
              variant="outline" 
              onClick={handleMaxClick}
              disabled={!tokenBalance || !!signatureDetails}
            >
              最大
            </Button>
          </div>
          {tokenBalance && tokenBalance > 0n ? (
            <p className="text-sm text-muted-foreground">
              可用余额: {formatEther(tokenBalance as bigint)} 代币
            </p>
          ) : null}
        </div>

        {/* 截止时间 */}
        <div className="space-y-2">
          <Label htmlFor="permit2-deadline">签名截止时间</Label>
          <div className="flex space-x-2">
            <Input
              id="permit2-deadline"
              type="datetime-local"
              value={deadline}
              onChange={(e) => setDeadline(e.target.value)}
              className="flex-1"
              disabled={!!signatureDetails}
            />
            <Button 
              variant="outline" 
              onClick={handleSetDefaultDeadline}
              disabled={!!signatureDetails}
            >
              1小时
            </Button>
          </div>
        </div>

        {/* Nonce */}
        <div className="space-y-2">
          <Label htmlFor="permit2-nonce">Nonce</Label>
          <div className="flex space-x-2">
            <Input
              id="permit2-nonce"
              type="number"
              placeholder="输入 nonce 值"
              value={nonce}
              onChange={(e) => setNonce(e.target.value)}
              className="flex-1"
              disabled={!!signatureDetails}
            />
            <Button 
              variant="outline" 
              onClick={handleSetDefaultNonce}
              disabled={!!signatureDetails}
            >
              随机
            </Button>
          </div>
          <p className="text-xs text-muted-foreground">
            Nonce 用于防止重放攻击，每次签名应使用不同的值
          </p>
        </div>

        {/* 错误提示 */}
        {isAmountValid && !hasEnoughBalance ? (
          <p className="text-sm text-destructive">
            余额不足
          </p>
        ) : null}

        {deadline && !isDeadlineValid ? (
          <p className="text-sm text-destructive">
            截止时间必须在未来
          </p>
        ) : null}

        {/* Permit2 授权检查和按钮 */}
        {permit2Allowance !== undefined && amountBigInt > 0n ? (
          permit2Allowance < amountBigInt ? (
            <div className="space-y-2 p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
              <div className="flex items-center space-x-2">
                <AlertCircle className="h-4 w-4 text-yellow-600" />
                <span className="text-sm font-medium text-yellow-800">
                  需要授权 Permit2 合约
                </span>
              </div>
              <p className="text-xs text-yellow-700">
                当前授权额度: {formatEther(permit2Allowance)} 代币
                <br />
                需要授权额度: {formatEther(amountBigInt)} 代币
              </p>
              <Button 
                onClick={handleApprovePermit2}
                disabled={isWritePending || isTxLoading}
                className="w-full"
                variant="outline"
              >
                {(isWritePending || isTxLoading) && txType === 'approve' && (
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                )}
                {(isWritePending || isTxLoading) && txType === 'approve' ? '授权中...' : '授权 Permit2 合约'}
              </Button>
            </div>
          ) : (
            <div className="flex items-center space-x-2 p-3 bg-green-50 border border-green-200 rounded-lg">
              <CheckCircle className="h-4 w-4 text-green-600" />
              <span className="text-sm text-green-800">
                Permit2 授权充足 ({formatEther(permit2Allowance)} 代币)
              </span>
            </div>
          )
        ) : null}

        {/* 签名按钮 */}
        {!signatureDetails && (
          <Button 
            onClick={handlePermit2Deposit}
            disabled={!canSign || isSigning}
            className="w-full"
            variant="outline"
          >
            {isSigning && (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            )}
            {isSigning ? '签名中...' : '生成 Permit2 签名'}
          </Button>
        )}

        {/* 签名详情 */}
        {signatureDetails && (
          <div className="space-y-4 p-4 bg-muted/50 rounded-lg border">
            <div className="flex items-center justify-between">
              <h4 className="font-semibold text-green-600">✓ Permit2 签名已生成</h4>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setShowTechnicalDetails(!showTechnicalDetails)}
              >
                {showTechnicalDetails ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                {showTechnicalDetails ? '隐藏' : '显示'}详情
              </Button>
            </div>
            
            {showTechnicalDetails && (
              <div className="space-y-3 text-xs">
                <div>
                  <div className="flex items-center justify-between mb-1">
                    <span className="font-medium">签名:</span>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => copyToClipboard(signatureDetails.signature, '签名')}
                    >
                      <Copy className="h-3 w-3" />
                    </Button>
                  </div>
                  <code className="block p-2 bg-background rounded text-xs break-all">
                    {signatureDetails.signature}
                  </code>
                </div>
                
                <div className="grid grid-cols-3 gap-2">
                  <div>
                    <span className="font-medium">r:</span>
                    <code className="block p-1 bg-background rounded text-xs break-all">
                      {signatureDetails.r}
                    </code>
                  </div>
                  <div>
                    <span className="font-medium">s:</span>
                    <code className="block p-1 bg-background rounded text-xs break-all">
                      {signatureDetails.s}
                    </code>
                  </div>
                  <div>
                    <span className="font-medium">v:</span>
                    <code className="block p-1 bg-background rounded text-xs">
                      {signatureDetails.v}
                    </code>
                  </div>
                </div>
              </div>
            )}
          </div>
        )}

        {/* 执行存款按钮 */}
        {signatureDetails && (
          <Button 
            onClick={handleExecuteDeposit}
            disabled={!canExecute}
            className="w-full"
          >
            {isTxLoading && (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            )}
            {isTxLoading ? '存款中...' : '执行 Permit2 存款'}
          </Button>
        )}

        {/* 重置按钮 */}
        {signatureDetails && !isTxLoading && (
          <Button 
            onClick={() => {
              setSignatureDetails(null)
              setAmount('')
              setDeadline('')
              setNonce('')
            }}
            variant="outline"
            className="w-full"
          >
            重新签名
          </Button>
        )}
      </CardContent>
    </Card>
  )
}