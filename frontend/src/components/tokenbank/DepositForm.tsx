import React, { useState } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card'
import { Button } from '../ui/button'
import { Input } from '../ui/input'
import { Label } from '../ui/label'
import { useToast } from '../ui/use-toast'
import { formatEther, parseEther } from '../../lib/utils'
import { TOKEN_BANK_ABI, ERC20_ABI } from '../../lib/contracts'
import { ArrowDownToLine, Loader2 } from 'lucide-react'

interface DepositFormProps {
  tokenBankAddress: string
  tokenAddress: string
}

export function DepositForm({ tokenBankAddress, tokenAddress }: DepositFormProps) {
  const [amount, setAmount] = useState('')
  const [isApproving, setIsApproving] = useState(false)
  const { address } = useAccount()
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

  // 读取授权额度
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address ? [address as `0x${string}`, tokenBankAddress as `0x${string}`] : undefined,
    query: {
      enabled: !!address,
    },
  })

  // 写入合约
  const { writeContract, data: writeData, isPending: isWritePending } = useWriteContract()

  // 存储最后一次交易的哈希
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
        setIsApproving(false)
        refetchAllowance()
        toast({
          title: "授权成功",
          description: "代币授权已完成，现在可以进行存款",
        })
      } else if (txType === 'deposit') {
        setAmount('')
        toast({
          title: "存款成功",
          description: `成功存入 ${amount} 代币到 TokenBank`,
        })
      }
      setLastTxHash(undefined)
      setTxType(undefined)
    }
  }, [isTxLoading, lastTxHash, txType, amount, toast, refetchAllowance, setIsApproving])

  const handleApprove = async () => {
    if (!amount || parseFloat(amount) <= 0) return
    setIsApproving(true)
    setTxType('approve')
    
    try {
      writeContract({
        address: tokenAddress as `0x${string}`,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [tokenBankAddress as `0x${string}`, parseEther(amount)],
      })
    } catch (error: any) {
      setIsApproving(false)
      setTxType(undefined)
      toast({
        title: "授权失败",
        description: error.message,
        variant: "destructive",
      })
    }
  }

  const handleDeposit = async () => {
    if (!amount || parseFloat(amount) <= 0) return
    setTxType('deposit')
    
    try {
      writeContract({
        address: tokenBankAddress as `0x${string}`,
        abi: TOKEN_BANK_ABI,
        functionName: 'deposit',
        args: [parseEther(amount)],
      })
    } catch (error: any) {
      setTxType(undefined)
      toast({
        title: "存款失败",
        description: error.message,
        variant: "destructive",
      })
    }
  }

  const handleMaxClick = () => {
    if (tokenBalance) {
      setAmount(formatEther(tokenBalance as bigint))
    }
  }

  const isAmountValid = amount && parseFloat(amount) > 0
  const amountBigInt = isAmountValid ? parseEther(amount) : 0n
  const hasEnoughBalance = tokenBalance && amountBigInt <= (tokenBalance as bigint)
  const hasEnoughAllowance = allowance && amountBigInt <= (allowance as bigint)
  const needsApproval = isAmountValid && !hasEnoughAllowance

  if (!address) {
    return (
      <Card className="w-full">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <ArrowDownToLine className="h-5 w-5" />
            存款
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
          <ArrowDownToLine className="h-5 w-5" />
          存款到 TokenBank
        </CardTitle>
        <CardDescription>
          将您的代币存入 TokenBank 合约
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="deposit-amount">存款金额</Label>
          <div className="flex space-x-2">
            <Input
              id="deposit-amount"
              type="number"
              placeholder="输入存款金额"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="flex-1"
            />
            <Button 
              variant="outline" 
              onClick={handleMaxClick}
              disabled={!tokenBalance}
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

        {/* 错误提示 */}
        {isAmountValid && !hasEnoughBalance ? (
          <p className="text-sm text-destructive">
            余额不足
          </p>
        ) : null}

        {/* 授权按钮 */}
        {needsApproval && hasEnoughBalance ? (
          <Button 
            onClick={handleApprove}
            disabled={isApproving || (isTxLoading && txType === 'approve') || isWritePending}
            className="w-full"
            variant="outline"
          >
            {(isApproving || (isTxLoading && txType === 'approve')) && (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            )}
            {isApproving || (isTxLoading && txType === 'approve') ? '授权中...' : '授权代币'}
          </Button>
        ) : null}

        {/* 存款按钮 */}
        <Button 
          onClick={handleDeposit}
          disabled={
            !isAmountValid || 
            !hasEnoughBalance || 
            needsApproval ||
            (isTxLoading && txType === 'deposit') ||
            isWritePending
          }
          className="w-full"
        >
          {(isTxLoading && txType === 'deposit') && (
            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
          )}
          {isTxLoading && txType === 'deposit' ? '存款中...' : '存款'}
        </Button>
      </CardContent>
    </Card>
  )
}