import { useChainId } from 'wagmi'
import { sepolia } from 'viem/chains'

export function NetworkStatus() {
  const chainId = useChainId()

  return (
    <div className="flex justify-center">
      <div className="glass-effect px-6 py-3 rounded-lg border border-border/50">
        <div className="flex items-center gap-2">
          <div className={`w-2 h-2 rounded-full ${
            chainId === sepolia.id ? 'bg-green-500' : 'bg-yellow-500'
          } animate-pulse`}></div>
          <span className="text-sm font-medium">
            {chainId === sepolia.id ? '✅ Sepolia 测试网络' : 
             chainId === 31337 ? '🏠 本地网络' : 
             `⚠️ 当前网络: ${chainId}`}
          </span>
        </div>
      </div>
    </div>
  )
}