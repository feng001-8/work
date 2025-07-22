import { useAccount, useWatchContractEvent, useChainId } from 'wagmi'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { formatEther } from '@/lib/utils'
import { TOKEN_BANK_ABI } from '@/lib/contracts'
import { History, ExternalLink, ArrowDownToLine, ArrowUpFromLine } from 'lucide-react'
import { useState, useEffect } from 'react'
import { TransactionDetails } from './TransactionDetails'

interface Transaction {
  hash: string
  type: 'deposit' | 'withdraw'
  amount: bigint
  timestamp: number
  blockNumber: bigint
  gasUsed?: string
  gasPrice?: string
  confirmations?: number
}

interface TransactionHistoryProps {
  tokenBankAddress: string
}

export function TransactionHistory({ tokenBankAddress }: TransactionHistoryProps) {
  const { address } = useAccount()
  const chainId = useChainId()
  const [transactions, setTransactions] = useState<Transaction[]>([])
  const [selectedTx, setSelectedTx] = useState<string | null>(null)

  // 获取交易详情
  const fetchTransactionDetails = async (txHash: string) => {
    try {
      const apiKey = import.meta.env.VITE_ETHERSCAN_API_KEY
      const baseUrl = chainId === 11155111 
        ? 'https://api-sepolia.etherscan.io/api'
        : 'https://api.etherscan.io/api'
      
      const response = await fetch(
        `${baseUrl}?module=proxy&action=eth_getTransactionByHash&txhash=${txHash}&apikey=${apiKey}`
      )
      const data = await response.json()
      
      if (data.result) {
        const receiptResponse = await fetch(
          `${baseUrl}?module=proxy&action=eth_getTransactionReceipt&txhash=${txHash}&apikey=${apiKey}`
        )
        const receiptData = await receiptResponse.json()
        
        return {
          gasUsed: receiptData.result?.gasUsed ? parseInt(receiptData.result.gasUsed, 16).toString() : undefined,
          gasPrice: data.result?.gasPrice ? formatEther(BigInt(data.result.gasPrice)) : undefined,
          confirmations: receiptData.result?.confirmations
        }
      }
      return null
    } catch (error) {
      console.error('Error fetching transaction details:', error)
      return null
    }
  }

  // 监听存款事件
  useWatchContractEvent({
    address: tokenBankAddress as `0x${string}`,
    abi: TOKEN_BANK_ABI,
    eventName: 'Deposit',
    onLogs: async (logs) => {
      for (const log of logs) {
        if (log.args.user === address) {
          const details = await fetchTransactionDetails(log.transactionHash)
          const newTransaction: Transaction = {
            hash: log.transactionHash,
            type: 'deposit',
            amount: log.args.amount as bigint,
            timestamp: Date.now(),
            blockNumber: log.blockNumber,
            ...(details || {})
          }
          setTransactions(prev => {
            if (prev.some(tx => tx.hash === newTransaction.hash)) {
              return prev
            }
            return [newTransaction, ...prev].slice(0, 10)
          })
        }
      }
    },
  })

  // 监听取款事件
  useWatchContractEvent({
    address: tokenBankAddress as `0x${string}`,
    abi: TOKEN_BANK_ABI,
    eventName: 'Withdraw',
    onLogs: async (logs) => {
      for (const log of logs) {
        if (log.args.user === address) {
          const details = await fetchTransactionDetails(log.transactionHash)
          const newTransaction: Transaction = {
            hash: log.transactionHash,
            type: 'withdraw',
            amount: log.args.amount as bigint,
            timestamp: Date.now(),
            blockNumber: log.blockNumber,
            ...(details || {})
          }
          setTransactions(prev => {
            if (prev.some(tx => tx.hash === newTransaction.hash)) {
              return prev
            }
            return [newTransaction, ...prev].slice(0, 10)
          })
        }
      }
    },
  })

  // 清空交易历史当地址改变时
  useEffect(() => {
    setTransactions([])
  }, [address])

  const getExplorerUrl = (hash: string) => {
    // 根据链 ID 返回对应的区块浏览器 URL
    if (chainId === 11155111) { // Sepolia
      return `https://sepolia.etherscan.io/tx/${hash}`
    } else if (chainId === 31337) { // Localhost
      return `#` // 本地网络没有区块浏览器
    }
    return `https://etherscan.io/tx/${hash}` // 默认使用 Etherscan
  }

  const formatTimestamp = (timestamp: number) => {
    return new Date(timestamp).toLocaleString('zh-CN')
  }

  if (!address) {
    return (
      <Card className="w-full">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <History className="h-5 w-5" />
            交易历史
          </CardTitle>
          <CardDescription>请先连接钱包查看交易历史</CardDescription>
        </CardHeader>
      </Card>
    )
  }

  return (
    <>
      <Card className="w-full">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <History className="h-5 w-5" />
            交易历史
          </CardTitle>
          <CardDescription>
            您最近的存款和取款记录
          </CardDescription>
        </CardHeader>
        <CardContent>
          {transactions.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              <History className="h-12 w-12 mx-auto mb-4 opacity-50" />
              <p>暂无交易记录</p>
              <p className="text-sm">进行存款或取款后，交易记录将显示在这里</p>
            </div>
          ) : (
            <div className="space-y-4">
              {transactions.map((tx) => (
                <div key={tx.hash} className="flex items-center justify-between p-4 border rounded-lg hover:bg-muted/50 transition-colors cursor-pointer" onClick={() => setSelectedTx(tx.hash)}>
                  <div className="flex items-center gap-3">
                    <div className={`p-2 rounded-full ${tx.type === 'deposit' ? 'bg-green-100 text-green-600 dark:bg-green-900 dark:text-green-400' : 'bg-blue-100 text-blue-600 dark:bg-blue-900 dark:text-blue-400'}`}>
                      {tx.type === 'deposit' ? (
                        <ArrowDownToLine className="h-4 w-4" />
                      ) : (
                        <ArrowUpFromLine className="h-4 w-4" />
                      )}
                    </div>
                    <div>
                      <p className="font-medium">
                        {tx.type === 'deposit' ? '存款' : '取款'}
                      </p>
                      <p className="text-sm text-muted-foreground">
                        {formatTimestamp(tx.timestamp)}
                      </p>
                      {tx.gasUsed && tx.gasPrice && (
                        <p className="text-xs text-muted-foreground">
                          Gas: {tx.gasUsed} @ {tx.gasPrice} ETH
                        </p>
                      )}
                      {tx.confirmations && (
                        <p className="text-xs text-muted-foreground">
                          确认数: {tx.confirmations}
                        </p>
                      )}
                    </div>
                  </div>
                  <div className="text-right">
                    <p className={`font-medium ${tx.type === 'deposit' ? 'text-green-600' : 'text-blue-600'}`}>
                      {tx.type === 'deposit' ? '+' : '-'}{formatEther(tx.amount)}
                    </p>
                    <a 
                      href={getExplorerUrl(tx.hash)}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-sm text-muted-foreground hover:text-foreground flex items-center gap-1"
                    >
                      查看交易
                      <ExternalLink className="h-3 w-3" />
                    </a>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
      
      <TransactionDetails
        hash={selectedTx || ''}
        isOpen={!!selectedTx}
        onClose={() => setSelectedTx(null)}
      />
    </>
  )
}