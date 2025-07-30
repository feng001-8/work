import React, { useState } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt, useChainId } from 'wagmi'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card'
import { Button } from '../ui/button'
import { Input } from '../ui/input'
import { Label } from '../ui/label'
import { useToast } from '../ui/use-toast'
import { formatEther, parseEther } from '../../lib/utils'
import { TOKEN_BANK_ABI, ERC20_ABI } from '../../lib/contracts'
import { PenTool, Loader2, Shield, Zap, Copy, Eye, EyeOff } from 'lucide-react'
import { signTypedData } from '@wagmi/core'
import { config } from '../../lib/wagmi'
import { keccak256, toHex } from 'viem'

interface PermitDepositFormProps {
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

export function PermitDepositForm({ tokenBankAddress, tokenAddress }: PermitDepositFormProps) {
  const [amount, setAmount] = useState('')
  const [deadline, setDeadline] = useState('')
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

  // 读取代币名称（用于签名）
  const { data: tokenName } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'name',
  })

  // 读取 nonces（用于签名）
  const { data: nonces } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'nonces',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  })

  // 写入合约
  const { writeContract, data: writeData, isPending: isWritePending } = useWriteContract()

  // 存储最后一次交易的哈希
  const [lastTxHash, setLastTxHash] = useState<`0x${string}` | undefined>()

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
      setAmount('')
      setDeadline('')
      setSignatureDetails(null)
      setShowTechnicalDetails(false)
      toast({
        title: "签名存款成功",
        description: `成功通过离线签名存入 ${amount} 代币到 TokenBank`,
      })
      setLastTxHash(undefined)
    }
  }, [isTxLoading, lastTxHash, amount, toast])

  const handlePermitDeposit = async () => {
    if (!amount || parseFloat(amount) <= 0 || !deadline || !address || !tokenName || nonces === undefined) {
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
      // 构建 EIP-2612 签名数据
      const domain = {
        name: tokenName as string,
        version: '1',
        chainId: chainId,
        verifyingContract: tokenAddress as `0x${string}`,
      }

      const types = {
        Permit: [
          { name: 'owner', type: 'address' },
          { name: 'spender', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'nonce', type: 'uint256' },
          { name: 'deadline', type: 'uint256' },
        ],
      }

      const message = {
        owner: address,
        spender: tokenBankAddress as `0x${string}`,
        value: parseEther(amount),
        nonce: nonces as bigint,
        deadline: BigInt(deadlineTimestamp),
      }

      // 请求用户签名
      const signature = await signTypedData(config, {
        domain,
        types,
        primaryType: 'Permit',
        message,
      })

      // 解析签名
      const r = signature.slice(0, 66) as `0x${string}`
      const s = ('0x' + signature.slice(66, 130)) as `0x${string}`
      const v = parseInt(signature.slice(130, 132), 16)

      // 计算域分隔符哈希
      const domainTypeHash = keccak256(toHex('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'))
      const nameHash = keccak256(toHex(domain.name))
      const versionHash = keccak256(toHex(domain.version))
      const domainSeparator = keccak256(
        `0x${domainTypeHash.slice(2)}${nameHash.slice(2)}${versionHash.slice(2)}${chainId.toString(16).padStart(64, '0')}${domain.verifyingContract.slice(2).padStart(64, '0')}`
      )

      // 计算消息哈希
      const permitTypeHash = keccak256(toHex('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'))
      const messageHash = keccak256(
        `0x${permitTypeHash.slice(2)}${address.slice(2).padStart(64, '0')}${tokenBankAddress.slice(2).padStart(64, '0')}${parseEther(amount).toString(16).padStart(64, '0')}${(nonces as bigint).toString(16).padStart(64, '0')}${BigInt(deadlineTimestamp).toString(16).padStart(64, '0')}`
      )

      // 计算最终的 TypedData 哈希
      const typedDataHash = keccak256(`0x1901${domainSeparator.slice(2)}${messageHash.slice(2)}`)

      // 存储签名技术细节
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

      setIsSigning(false)

      // 调用 permitDeposit 函数
      writeContract({
        address: tokenBankAddress as `0x${string}`,
        abi: TOKEN_BANK_ABI,
        functionName: 'permitDeposit',
        args: [
          address,
          parseEther(amount),
          BigInt(deadlineTimestamp),
          v,
          r,
          s,
        ],
      })
    } catch (error: any) {
      setIsSigning(false)
      toast({
        title: "签名失败",
        description: error.message || "用户取消签名或签名过程出错",
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
  const hasEnoughBalance = tokenBalance && amountBigInt <= (tokenBalance as bigint)
  const isDeadlineValid = deadline && new Date(deadline).getTime() > Date.now()

  if (!address) {
    return (
      <Card className="w-full glass-effect border-primary/20">
        <CardHeader className="bg-gradient-to-r from-primary/5 to-accent/5 rounded-t-lg">
          <CardTitle className="flex items-center gap-2">
            <PenTool className="h-5 w-5 text-primary" />
            签名存款
          </CardTitle>
          <CardDescription>请先连接钱包</CardDescription>
        </CardHeader>
      </Card>
    )
  }

  return (
    <Card className="w-full glass-effect hover-lift border-primary/20">
      <CardHeader className="bg-gradient-to-r from-primary/5 to-accent/5 rounded-t-lg">
        <CardTitle className="flex items-center gap-2">
          <PenTool className="h-5 w-5 text-primary" />
          <span className="bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
            离线签名存款
          </span>
          <Shield className="h-4 w-4 text-accent animate-pulse" />
        </CardTitle>
        <CardDescription className="text-base">
          使用 EIP-2612 标准进行无 Gas 费授权存款
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-6 p-6">
        {/* 存款金额 */}
        <div className="space-y-3">
          <Label htmlFor="permit-amount" className="text-sm font-semibold text-foreground">
            存款金额
          </Label>
          <div className="flex space-x-2">
            <Input
              id="permit-amount"
              type="number"
              placeholder="输入存款金额"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="flex-1 glass-effect"
            />
            <Button 
              variant="outline" 
              onClick={handleMaxClick}
              disabled={!tokenBalance}
              className="hover-lift"
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

        {/* 签名截止时间 */}
        <div className="space-y-3">
          <Label htmlFor="permit-deadline" className="text-sm font-semibold text-foreground">
            签名截止时间
          </Label>
          <div className="flex space-x-2">
            <Input
              id="permit-deadline"
              type="datetime-local"
              value={deadline}
              onChange={(e) => setDeadline(e.target.value)}
              className="flex-1 glass-effect"
            />
            <Button 
              variant="outline" 
              onClick={handleSetDefaultDeadline}
              className="hover-lift"
            >
              +1小时
            </Button>
          </div>
          <p className="text-xs text-muted-foreground">
            签名将在此时间后失效，建议设置较短的有效期以提高安全性
          </p>
        </div>

        {/* 错误提示 */}
        {isAmountValid && !hasEnoughBalance && (
          <div className="glass-effect p-3 rounded-lg border border-destructive/30 bg-destructive/5">
            <p className="text-sm text-destructive font-medium">
              余额不足
            </p>
          </div>
        )}

        {deadline && !isDeadlineValid && (
          <div className="glass-effect p-3 rounded-lg border border-destructive/30 bg-destructive/5">
            <p className="text-sm text-destructive font-medium">
              截止时间必须在未来
            </p>
          </div>
        )}

        {/* 签名存款按钮 */}
        <Button 
          onClick={handlePermitDeposit}
          disabled={
            !isAmountValid || 
            !hasEnoughBalance || 
            !isDeadlineValid ||
            isSigning ||
            isTxLoading ||
            isWritePending
          }
          className="w-full gradient-trae hover-glow"
          size="lg"
        >
          {isSigning && (
            <PenTool className="mr-2 h-4 w-4 animate-pulse" />
          )}
          {isTxLoading && (
            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
          )}
          {!isSigning && !isTxLoading && (
            <Zap className="mr-2 h-4 w-4" />
          )}
          {isSigning ? '请在钱包中签名...' : 
           isTxLoading ? '存款交易确认中...' : 
           '签名并存款'}
        </Button>

        {/* 签名技术细节 */}
        {signatureDetails && (
          <div className="glass-effect p-4 rounded-lg border border-accent/20 bg-accent/5">
            <div className="flex items-center justify-between mb-3">
              <h4 className="text-sm font-semibold text-foreground flex items-center gap-2">
                <PenTool className="h-4 w-4 text-accent" />
                EIP-712 签名技术细节
              </h4>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setShowTechnicalDetails(!showTechnicalDetails)}
                className="h-8 px-2"
              >
                {showTechnicalDetails ? (
                  <EyeOff className="h-4 w-4" />
                ) : (
                  <Eye className="h-4 w-4" />
                )}
              </Button>
            </div>
            
            {showTechnicalDetails && (
              <div className="space-y-4">
                {/* 签名组件 */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                  <div className="space-y-2">
                    <Label className="text-xs font-medium text-muted-foreground">签名 R 值</Label>
                    <div className="flex items-center gap-2">
                      <code className="text-xs bg-muted p-2 rounded flex-1 font-mono break-all">
                        {signatureDetails.r}
                      </code>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => copyToClipboard(signatureDetails.r, 'R 值')}
                        className="h-8 w-8 p-0"
                      >
                        <Copy className="h-3 w-3" />
                      </Button>
                    </div>
                  </div>
                  
                  <div className="space-y-2">
                    <Label className="text-xs font-medium text-muted-foreground">签名 S 值</Label>
                    <div className="flex items-center gap-2">
                      <code className="text-xs bg-muted p-2 rounded flex-1 font-mono break-all">
                        {signatureDetails.s}
                      </code>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => copyToClipboard(signatureDetails.s, 'S 值')}
                        className="h-8 w-8 p-0"
                      >
                        <Copy className="h-3 w-3" />
                      </Button>
                    </div>
                  </div>
                  
                  <div className="space-y-2">
                    <Label className="text-xs font-medium text-muted-foreground">恢复 ID (V)</Label>
                    <div className="flex items-center gap-2">
                      <code className="text-xs bg-muted p-2 rounded flex-1 font-mono">
                        {signatureDetails.v}
                      </code>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => copyToClipboard(signatureDetails.v.toString(), 'V 值')}
                        className="h-8 w-8 p-0"
                      >
                        <Copy className="h-3 w-3" />
                      </Button>
                    </div>
                  </div>
                </div>

                {/* 哈希值 */}
                <div className="space-y-3">
                  <div className="space-y-2">
                    <Label className="text-xs font-medium text-muted-foreground">域分隔符哈希 (Domain Separator)</Label>
                    <div className="flex items-center gap-2">
                      <code className="text-xs bg-muted p-2 rounded flex-1 font-mono break-all">
                        {signatureDetails.domainSeparator}
                      </code>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => copyToClipboard(signatureDetails.domainSeparator, '域分隔符哈希')}
                        className="h-8 w-8 p-0"
                      >
                        <Copy className="h-3 w-3" />
                      </Button>
                    </div>
                  </div>
                  
                  <div className="space-y-2">
                    <Label className="text-xs font-medium text-muted-foreground">消息哈希 (Message Hash)</Label>
                    <div className="flex items-center gap-2">
                      <code className="text-xs bg-muted p-2 rounded flex-1 font-mono break-all">
                        {signatureDetails.messageHash}
                      </code>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => copyToClipboard(signatureDetails.messageHash, '消息哈希')}
                        className="h-8 w-8 p-0"
                      >
                        <Copy className="h-3 w-3" />
                      </Button>
                    </div>
                  </div>
                  
                  <div className="space-y-2">
                    <Label className="text-xs font-medium text-muted-foreground">TypedData 哈希 (最终签名哈希)</Label>
                    <div className="flex items-center gap-2">
                      <code className="text-xs bg-muted p-2 rounded flex-1 font-mono break-all">
                        {signatureDetails.typedDataHash}
                      </code>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => copyToClipboard(signatureDetails.typedDataHash, 'TypedData 哈希')}
                        className="h-8 w-8 p-0"
                      >
                        <Copy className="h-3 w-3" />
                      </Button>
                    </div>
                  </div>
                  
                  <div className="space-y-2">
                    <Label className="text-xs font-medium text-muted-foreground">完整签名</Label>
                    <div className="flex items-center gap-2">
                      <code className="text-xs bg-muted p-2 rounded flex-1 font-mono break-all">
                        {signatureDetails.signature}
                      </code>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => copyToClipboard(signatureDetails.signature, '完整签名')}
                        className="h-8 w-8 p-0"
                      >
                        <Copy className="h-3 w-3" />
                      </Button>
                    </div>
                  </div>
                </div>

                {/* 签名验证说明 */}
                <div className="bg-muted/50 p-3 rounded-lg">
                  <h5 className="text-xs font-semibold text-foreground mb-2">合约验证过程</h5>
                  <ul className="text-xs text-muted-foreground space-y-1">
                    <li>1. 合约重新计算域分隔符和消息哈希</li>
                    <li>2. 使用 ecrecover(typedDataHash, v, r, s) 恢复签名者地址</li>
                    <li>3. 验证恢复的地址是否与 owner 参数匹配</li>
                    <li>4. 检查 nonce 是否正确且未被使用</li>
                    <li>5. 验证 deadline 是否未过期</li>
                  </ul>
                </div>
              </div>
            )}
          </div>
        )}

        {/* 技术细节提示 */}
        {!signatureDetails && (
          <div className="glass-effect p-4 rounded-lg border border-accent/20 bg-accent/5">
            <div className="flex items-start gap-3">
              <PenTool className="h-5 w-5 text-accent mt-0.5 flex-shrink-0" />
              <div className="space-y-2">
                <h4 className="text-sm font-semibold text-foreground">📚 学习提示</h4>
                <p className="text-xs text-muted-foreground">
                  完成一次签名操作后，这里将显示详细的 EIP-712 签名技术细节，包括：
                </p>
                <ul className="text-xs text-muted-foreground space-y-1 ml-4">
                  <li>• 签名的 R、S、V 值（椭圆曲线签名组件）</li>
                  <li>• 域分隔符哈希和消息哈希</li>
                  <li>• TypedData 最终签名哈希</li>
                  <li>• 合约验证签名的详细步骤说明</li>
                </ul>
                <p className="text-xs text-accent font-medium">
                  💡 填写存款信息并点击"签名并存款"按钮开始体验！
                </p>
              </div>
            </div>
          </div>
        )}

        {/* 说明信息 */}
        <div className="glass-effect p-4 rounded-lg border border-primary/20 bg-primary/5">
          <div className="flex items-start gap-3">
            <Shield className="h-5 w-5 text-primary mt-0.5 flex-shrink-0" />
            <div className="space-y-2">
              <h4 className="text-sm font-semibold text-foreground">离线签名存款优势</h4>
              <ul className="text-xs text-muted-foreground space-y-1">
                <li>• 无需预先授权交易，节省 Gas 费用</li>
                <li>• 一次签名完成授权和存款，提升用户体验</li>
                <li>• 支持设置签名有效期，提高安全性</li>
                <li>• 符合 EIP-2612 标准，兼容性强</li>
              </ul>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}