import { Dialog, DialogContent, DialogHeader, DialogTitle } from './ui/dialog'
import { useEffect, useState } from 'react'
import { useChainId } from 'wagmi'
import { formatEther } from '../lib/utils'

interface TransactionDetailsProps {
  hash: string
  isOpen: boolean
  onClose: () => void
}

interface TransactionDetail {
  blockNumber: string
  timestamp: string
  from: string
  to: string
  value: string
  gasPrice: string
  gasUsed: string
  nonce: string
  status: string
}

export function TransactionDetails({ hash, isOpen, onClose }: TransactionDetailsProps) {
  const chainId = useChainId()
  const [details, setDetails] = useState<TransactionDetail | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (isOpen && hash) {
      fetchTransactionDetails()
    }
  }, [isOpen, hash])

  const fetchTransactionDetails = async () => {
    try {
      setLoading(true)
      const apiKey = import.meta.env.VITE_ETHERSCAN_API_KEY as string
      const baseUrl = chainId === 11155111
        ? 'https://api-sepolia.etherscan.io/api'
        : 'https://api.etherscan.io/api'

      // 获取交易详情
      const txResponse = await fetch(
        `${baseUrl}?module=proxy&action=eth_getTransactionByHash&txhash=${hash}&apikey=${apiKey}`
      )
      const txData = await txResponse.json()

      // 获取交易收据
      const receiptResponse = await fetch(
        `${baseUrl}?module=proxy&action=eth_getTransactionReceipt&txhash=${hash}&apikey=${apiKey}`
      )
      const receiptData = await receiptResponse.json()

      // 获取区块信息
      const blockResponse = await fetch(
        `${baseUrl}?module=proxy&action=eth_getBlockByNumber&tag=0x${Number(txData.result.blockNumber).toString(16)}&boolean=true&apikey=${apiKey}`
      )
      const blockData = await blockResponse.json()

      if (txData.result && receiptData.result && blockData.result) {
        setDetails({
          blockNumber: parseInt(txData.result.blockNumber, 16).toString(),
          timestamp: new Date(parseInt(blockData.result.timestamp, 16) * 1000).toLocaleString('zh-CN'),
          from: txData.result.from,
          to: txData.result.to,
          value: formatEther(BigInt(txData.result.value)),
          gasPrice: formatEther(BigInt(txData.result.gasPrice)),
          gasUsed: parseInt(receiptData.result.gasUsed, 16).toString(),
          nonce: parseInt(txData.result.nonce, 16).toString(),
          status: receiptData.result.status === '0x1' ? '成功' : '失败'
        })
      }
    } catch (error) {
      console.error('Error fetching transaction details:', error)
    } finally {
      setLoading(false)
    }
  }

  return (
    <Dialog open={isOpen} onOpenChange={(open: boolean) => !open && onClose()}>
      <DialogContent className="sm:max-w-[600px]">
        <DialogHeader>
          <DialogTitle>交易详情</DialogTitle>
        </DialogHeader>
        {loading ? (
          <div className="py-8 text-center text-muted-foreground">
            加载中...
          </div>
        ) : details ? (
          <div className="space-y-4">
            <div className="grid grid-cols-3 gap-4 text-sm">
              <div className="col-span-1 text-muted-foreground">交易哈希</div>
              <div className="col-span-2 font-medium break-all">{hash}</div>

              <div className="col-span-1 text-muted-foreground">状态</div>
              <div className="col-span-2 font-medium">
                <span className={details.status === '成功' ? 'text-green-600' : 'text-red-600'}>
                  {details.status}
                </span>
              </div>

              <div className="col-span-1 text-muted-foreground">区块</div>
              <div className="col-span-2 font-medium">{details.blockNumber}</div>

              <div className="col-span-1 text-muted-foreground">时间戳</div>
              <div className="col-span-2 font-medium">{details.timestamp}</div>

              <div className="col-span-1 text-muted-foreground">发送方</div>
              <div className="col-span-2 font-medium break-all">{details.from}</div>

              <div className="col-span-1 text-muted-foreground">接收方</div>
              <div className="col-span-2 font-medium break-all">{details.to}</div>

              <div className="col-span-1 text-muted-foreground">数量</div>
              <div className="col-span-2 font-medium">{details.value} ETH</div>

              <div className="col-span-1 text-muted-foreground">Gas 价格</div>
              <div className="col-span-2 font-medium">{details.gasPrice} ETH</div>

              <div className="col-span-1 text-muted-foreground">Gas 使用量</div>
              <div className="col-span-2 font-medium">{details.gasUsed}</div>

              <div className="col-span-1 text-muted-foreground">Nonce</div>
              <div className="col-span-2 font-medium">{details.nonce}</div>
            </div>
          </div>
        ) : (
          <div className="py-8 text-center text-muted-foreground">
            无法获取交易详情
          </div>
        )}
      </DialogContent>
    </Dialog>
  )
}