import { useChainId, useAccount } from 'wagmi'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { CONTRACTS } from '@/lib/contracts'

export function DebugInfo() {
  const chainId = useChainId()
  const { address, isConnected } = useAccount()

  const getContractAddresses = () => {
    if (chainId === 11155111) { // Sepolia
      return {
        tokenBank: CONTRACTS.SEPOLIA.TOKEN_BANK,
        token: CONTRACTS.SEPOLIA.ERC20_TOKEN,
      }
    } else if (chainId === 31337) { // Localhost
      return {
        tokenBank: CONTRACTS.LOCALHOST.TOKEN_BANK,
        token: CONTRACTS.LOCALHOST.ERC20_TOKEN,
      }
    }
    return {
      tokenBank: CONTRACTS.LOCALHOST.TOKEN_BANK,
      token: CONTRACTS.LOCALHOST.ERC20_TOKEN,
    }
  }

  const { tokenBank, token } = getContractAddresses()

  return (
    <Card className="mb-4">
      <CardHeader>
        <CardTitle>调试信息</CardTitle>
      </CardHeader>
      <CardContent className="space-y-2 text-sm">
        <div><strong>钱包连接状态:</strong> {isConnected ? '已连接' : '未连接'}</div>
        <div><strong>钱包地址:</strong> {address || '未连接'}</div>
        <div><strong>当前链ID:</strong> {chainId || '未检测到'}</div>
        <div><strong>网络名称:</strong> {chainId === 31337 ? 'Localhost' : chainId === 11155111 ? 'Sepolia' : `Chain ${chainId}`}</div>
        <div><strong>TokenBank地址:</strong> {tokenBank}</div>
        <div><strong>ERC20代币地址:</strong> {token}</div>
        <div><strong>配置来源:</strong> {chainId === 31337 ? 'LOCALHOST配置' : chainId === 11155111 ? 'SEPOLIA配置' : '默认LOCALHOST配置'}</div>
      </CardContent>
    </Card>
  )
}