import React, { useState } from 'react';
import { useWatchContractEvent } from 'wagmi';
import { NFT_MARKET_ABI, CONTRACTS } from '../../lib/contracts';
import { formatEther } from 'viem';

interface EventLog {
  id: string;
  type: 'NFTListed' | 'NFTSold' | 'NFTListingCancelled';
  timestamp: string;
  data: any;
}

const NFTMarketEventListener: React.FC = () => {
  const [eventLogs, setEventLogs] = useState<EventLog[]>([]);

  // 监听NFT上架事件
  useWatchContractEvent({
    address: CONTRACTS.LOCALHOST.NFT_MARKET as `0x${string}`,
    abi: NFT_MARKET_ABI,
    eventName: 'NFTListed',
    onLogs(logs) {
      logs.forEach((log) => {
        const eventLog: EventLog = {
          id: `listed-${log.transactionHash}-${log.logIndex}`,
          type: 'NFTListed',
          timestamp: new Date().toLocaleString(),
          data: {
            listingId: log.args.listingId?.toString(),
            seller: log.args.seller,
            nftContract: log.args.nftContract,
            tokenId: log.args.tokenId?.toString(),
            price: log.args.price ? formatEther(log.args.price) : '0',
            transactionHash: log.transactionHash,
          },
        };
        
        console.log('🏷️ NFT上架事件:', {
          listingId: eventLog.data.listingId,
          seller: eventLog.data.seller,
          nftContract: eventLog.data.nftContract,
          tokenId: eventLog.data.tokenId,
          price: `${eventLog.data.price} ETH`,
          transactionHash: eventLog.data.transactionHash,
        });
        
        setEventLogs(prev => [eventLog, ...prev]);
      });
    },
  });

  // 监听NFT售出事件
  useWatchContractEvent({
    address: CONTRACTS.LOCALHOST.NFT_MARKET as `0x${string}`,
    abi: NFT_MARKET_ABI,
    eventName: 'NFTSold',
    onLogs(logs) {
      logs.forEach((log) => {
        const eventLog: EventLog = {
          id: `sold-${log.transactionHash}-${log.logIndex}`,
          type: 'NFTSold',
          timestamp: new Date().toLocaleString(),
          data: {
            listingId: log.args.listingId?.toString(),
            buyer: log.args.buyer,
            seller: log.args.seller,
            nftContract: log.args.nftContract,
            tokenId: log.args.tokenId?.toString(),
            price: log.args.price ? formatEther(log.args.price) : '0',
            transactionHash: log.transactionHash,
          },
        };
        
        console.log('💰 NFT售出事件:', {
          listingId: eventLog.data.listingId,
          buyer: eventLog.data.buyer,
          seller: eventLog.data.seller,
          nftContract: eventLog.data.nftContract,
          tokenId: eventLog.data.tokenId,
          price: `${eventLog.data.price} ETH`,
          transactionHash: eventLog.data.transactionHash,
        });
        
        setEventLogs(prev => [eventLog, ...prev]);
      });
    },
  });

  // 监听NFT取消上架事件
  useWatchContractEvent({
    address: CONTRACTS.LOCALHOST.NFT_MARKET as `0x${string}`,
    abi: NFT_MARKET_ABI,
    eventName: 'NFTListingCancelled',
    onLogs(logs) {
      logs.forEach((log) => {
        const eventLog: EventLog = {
          id: `cancelled-${log.transactionHash}-${log.logIndex}`,
          type: 'NFTListingCancelled',
          timestamp: new Date().toLocaleString(),
          data: {
            listingId: log.args.listingId?.toString(),
            transactionHash: log.transactionHash,
          },
        };
        
        console.log('❌ NFT取消上架事件:', {
          listingId: eventLog.data.listingId,
          transactionHash: eventLog.data.transactionHash,
        });
        
        setEventLogs(prev => [eventLog, ...prev]);
      });
    },
  });

  const getEventIcon = (type: EventLog['type']) => {
    switch (type) {
      case 'NFTListed':
        return '🏷️';
      case 'NFTSold':
        return '💰';
      case 'NFTListingCancelled':
        return '❌';
      default:
        return '📝';
    }
  };

  const getEventTitle = (type: EventLog['type']) => {
    switch (type) {
      case 'NFTListed':
        return 'NFT上架';
      case 'NFTSold':
        return 'NFT售出';
      case 'NFTListingCancelled':
        return 'NFT取消上架';
      default:
        return '未知事件';
    }
  };

  return (
    <div className="glass-effect border-border/50 bg-gradient-to-br from-card/80 to-card/40 backdrop-blur-sm hover:shadow-xl transition-all duration-300 rounded-xl p-6">
      <div className="flex items-center gap-3 mb-6">
        <div className="relative">
          <span className="text-3xl animate-pulse-glow">🎯</span>
        </div>
        <h2 className="text-2xl font-bold bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
          NFT市场事件监听
        </h2>
      </div>
      
      <div className="mb-6 p-4 bg-gradient-to-r from-primary/10 to-accent/10 border border-primary/20 rounded-xl backdrop-blur-sm">
        <div className="flex items-center gap-2 mb-2">
          <span className="text-lg">📡</span>
          <h3 className="font-semibold text-primary">监听状态</h3>
        </div>
        <p className="text-sm text-muted-foreground mb-2">
          正在监听NFT市场合约事件... 当有上架、购买或取消上架操作时，会在此显示并在控制台打印日志。
        </p>
        <div className="flex flex-col gap-1">
          <span className="text-xs text-muted-foreground font-medium">合约地址:</span>
          <code className="text-xs bg-muted/50 px-2 py-1 rounded font-mono break-all">{CONTRACTS.LOCALHOST.NFT_MARKET}</code>
        </div>
      </div>

      <div className="space-y-4 max-h-96 overflow-y-auto scrollbar-thin scrollbar-thumb-primary/20 scrollbar-track-transparent">
        {eventLogs.length === 0 ? (
          <div className="text-center py-12 animate-fade-in">
            <div className="mb-4">
              <span className="text-6xl opacity-20">📝</span>
            </div>
            <p className="text-lg font-medium text-muted-foreground mb-2">暂无事件记录</p>
            <p className="text-sm text-muted-foreground">执行NFT市场操作后，事件将在此显示</p>
          </div>
        ) : (
          eventLogs.map((log, index) => (
            <div
              key={log.id}
              className="border border-border/50 rounded-xl p-4 bg-gradient-to-r from-background/50 to-muted/20 hover:from-background/70 hover:to-muted/30 transition-all duration-300 hover:shadow-md animate-slide-up"
              style={{ animationDelay: `${index * 100}ms` }}
            >
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center space-x-3">
                  <div className="text-2xl animate-bounce-gentle">{getEventIcon(log.type)}</div>
                  <div>
                    <span className="font-semibold text-foreground text-lg">
                      {getEventTitle(log.type)}
                    </span>
                    <div className="text-xs text-muted-foreground mt-1">{log.timestamp}</div>
                  </div>
                </div>
                <div className="w-3 h-3 bg-primary rounded-full animate-pulse"></div>
              </div>
              
              <div className="space-y-3">
                {log.type === 'NFTListed' && (
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
                    <div className="space-y-2">
                      <div className="flex justify-between">
                        <span className="text-muted-foreground font-medium">上架ID:</span>
                        <span className="font-mono text-accent">{log.data.listingId}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-muted-foreground font-medium">Token ID:</span>
                        <span className="font-mono text-primary">{log.data.tokenId}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-muted-foreground font-medium">价格:</span>
                        <span className="font-semibold text-success">{log.data.price} ETH</span>
                      </div>
                    </div>
                    <div className="space-y-2">
                      <div className="flex flex-col gap-1">
                        <span className="text-muted-foreground font-medium text-xs">卖家:</span>
                        <code className="text-xs bg-muted/50 px-2 py-1 rounded font-mono break-all">{log.data.seller}</code>
                      </div>
                      <div className="flex flex-col gap-1">
                        <span className="text-muted-foreground font-medium text-xs">NFT合约:</span>
                        <code className="text-xs bg-muted/50 px-2 py-1 rounded font-mono break-all">{log.data.nftContract}</code>
                      </div>
                    </div>
                  </div>
                )}
                
                {log.type === 'NFTSold' && (
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
                    <div className="space-y-2">
                      <div className="flex justify-between">
                        <span className="text-muted-foreground font-medium">上架ID:</span>
                        <span className="font-mono text-accent">{log.data.listingId}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-muted-foreground font-medium">Token ID:</span>
                        <span className="font-mono text-primary">{log.data.tokenId}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-muted-foreground font-medium">成交价:</span>
                        <span className="font-semibold text-success">{log.data.price} ETH</span>
                      </div>
                    </div>
                    <div className="space-y-2">
                      <div className="flex flex-col gap-1">
                        <span className="text-muted-foreground font-medium text-xs">买家:</span>
                        <code className="text-xs bg-muted/50 px-2 py-1 rounded font-mono break-all">{log.data.buyer}</code>
                      </div>
                      <div className="flex flex-col gap-1">
                        <span className="text-muted-foreground font-medium text-xs">卖家:</span>
                        <code className="text-xs bg-muted/50 px-2 py-1 rounded font-mono break-all">{log.data.seller}</code>
                      </div>
                      <div className="flex flex-col gap-1">
                        <span className="text-muted-foreground font-medium text-xs">NFT合约:</span>
                        <code className="text-xs bg-muted/50 px-2 py-1 rounded font-mono break-all">{log.data.nftContract}</code>
                      </div>
                    </div>
                  </div>
                )}
                
                {log.type === 'NFTListingCancelled' && (
                  <div className="text-sm">
                    <div className="flex justify-between">
                      <span className="text-muted-foreground font-medium">上架ID:</span>
                      <span className="font-mono text-destructive">{log.data.listingId}</span>
                    </div>
                  </div>
                )}
                
                <div className="pt-2 border-t border-border/30">
                  <div className="flex flex-col gap-1">
                    <span className="text-xs text-muted-foreground font-medium">交易哈希:</span>
                    <code className="text-xs bg-muted/50 px-2 py-1 rounded font-mono break-all">{log.data.transactionHash}</code>
                  </div>
                </div>
              </div>
            </div>
          ))
        )}
      </div>
      
      {eventLogs.length > 0 && (
        <div className="mt-6 pt-4 border-t border-border/30">
          <button
            onClick={() => setEventLogs([])}
            className="flex items-center gap-2 text-sm text-destructive hover:text-destructive/80 transition-colors px-3 py-2 rounded-lg hover:bg-destructive/10 border border-destructive/20 hover:border-destructive/40"
          >
            <span className="text-base">🗑️</span>
            清空事件记录
          </button>
        </div>
      )}
    </div>
  );
};

export default NFTMarketEventListener;