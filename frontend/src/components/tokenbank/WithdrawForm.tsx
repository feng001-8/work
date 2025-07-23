import React, { useState } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card'
import { Button } from '../ui/button'
import { Input } from '../ui/input'
import { Label } from '../ui/label'
import { useToast } from '../ui/use-toast'
import { formatEther, parseEther } from '../../lib/utils'
import { TOKEN_BANK_ABI } from '../../lib/contracts'
import { ArrowUpFromLine, Loader2 } from 'lucide-react'

interface WithdrawFormProps {
  tokenBankAddress: string
}

export function WithdrawForm({ tokenBankAddress }: WithdrawFormProps) {
  const [amount, setAmount] = useState('')
  const { address } = useAccount()
  const { toast } = useToast()

  // 读取用户在银行的余额
  const { data: bankBalance } = useReadContract({
    address: tokenBankAddress as `0x${string}`,
    abi: TOKEN_BANK_ABI,
    functionName: 'getBankBalance',
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
      toast({
        title: "取款成功",
        description: `成功从 TokenBank 取出 ${amount} 代币`,
      })
      setLastTxHash(undefined)
    }
  }, [isTxLoading, lastTxHash, amount, toast])

  const handleWithdraw = async () => {
    if (!amount || parseFloat(amount) <= 0) return
    
    try {
      writeContract({
        address: tokenBankAddress as `0x${string}`,
        abi: TOKEN_BANK_ABI,
        functionName: 'withdraw',
        args: [parseEther(amount)],
      })
    } catch (error: any) {
      toast({
        title: "取款失败",
        description: error.message,
        variant: "destructive",
      })
    }
  }

  const handleMaxClick = () => {
    if (bankBalance) {
      setAmount(formatEther(bankBalance as bigint))
    }
  }

  const isAmountValid = amount && parseFloat(amount) > 0
  const amountBigInt = isAmountValid ? parseEther(amount) : 0n
  const hasEnoughBankBalance = bankBalance && amountBigInt <= (bankBalance as bigint)

  if (!address) {
    return (
      <Card className="w-full">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <ArrowUpFromLine className="h-5 w-5" />
            取款
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
          <ArrowUpFromLine className="h-5 w-5" />
          从 TokenBank 取款
        </CardTitle>
        <CardDescription>
          从 TokenBank 合约中取出您的代币
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="withdraw-amount">取款金额</Label>
          <div className="flex space-x-2">
            <Input
              id="withdraw-amount"
              type="number"
              placeholder="输入取款金额"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="flex-1"
            />
            <Button 
              variant="outline" 
              onClick={handleMaxClick}
              disabled={!bankBalance || bankBalance === 0n}
            >
              最大
            </Button>
          </div>
          {bankBalance && bankBalance > 0n ? (
            <p className="text-sm text-muted-foreground">
              银行存款: {formatEther(bankBalance)} 代币
            </p>
          ) : null}
        </div>

        {/* 错误提示 */}
        {isAmountValid && !hasEnoughBankBalance ? (
          <p className="text-sm text-destructive">
            银行存款余额不足
          </p>
        ) : null}

        {/* 无存款提示 */}
        {bankBalance !== undefined && bankBalance === 0n && (
          <p className="text-sm text-muted-foreground">
            您在 TokenBank 中没有存款
          </p>
        )}

        {/* 取款按钮 */}
        <Button 
          onClick={handleWithdraw}
          disabled={
            !isAmountValid || 
            !hasEnoughBankBalance ||
            isTxLoading ||
            isWritePending ||
            (bankBalance !== undefined && bankBalance === 0n)
          }
          className="w-full"
          variant="outline"
        >
          {isTxLoading && (
            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
          )}
          {isTxLoading ? '取款中...' : '取款'}
        </Button>
      </CardContent>
    </Card>
  )
}