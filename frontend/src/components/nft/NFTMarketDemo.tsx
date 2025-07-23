import React, { useState } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { NFT_MARKET_ABI, SIMPLE_NFT_ABI, ERC20_ABI, CONTRACTS } from '../../lib/contracts';
import { parseEther } from 'viem';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
import { Button } from '../ui/button';
import { Input } from '../ui/input';
import { Label } from '../ui/label';
import { useToast } from '../ui/use-toast';

const NFTMarketDemo: React.FC = () => {
  const { address } = useAccount();
  const { toast } = useToast();
  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
  });

  const [nftContract, setNftContract] = useState('');
  const [tokenId, setTokenId] = useState('');
  const [price, setPrice] = useState('');
  const [listingId, setListingId] = useState('');

  // 铸造NFT
  const mintNFT = async () => {
    if (!nftContract || !address) {
      toast({
        title: '错误',
        description: '请填写NFT合约地址',
        variant: 'destructive',
      });
      return;
    }

    try {
      writeContract({
        address: nftContract as `0x${string}`,
        abi: SIMPLE_NFT_ABI,
        functionName: 'mint',
        args: [address],
      });
    } catch (error) {
      console.error('铸造NFT失败:', error);
      toast({
        title: '错误',
        description: '铸造NFT失败',
        variant: 'destructive',
      });
    }
  };

  // 授权NFT给市场合约
  const approveNFT = async () => {
    if (!nftContract) {
      toast({
        title: '错误',
        description: '请填写NFT合约地址',
        variant: 'destructive',
      });
      return;
    }

    try {
      writeContract({
        address: nftContract as `0x${string}`,
        abi: SIMPLE_NFT_ABI,
        functionName: 'setApprovalForAll',
        args: [CONTRACTS.LOCALHOST.NFT_MARKET, true],
      });
    } catch (error) {
      console.error('授权NFT失败:', error);
      toast({
        title: '错误',
        description: '授权NFT失败',
        variant: 'destructive',
      });
    }
  };

  // 上架NFT
  const listNFT = async () => {
    if (!nftContract || !tokenId || !price) {
      toast({
        title: '错误',
        description: '请填写所有字段',
        variant: 'destructive',
      });
      return;
    }

    try {
      writeContract({
        address: CONTRACTS.LOCALHOST.NFT_MARKET as `0x${string}`,
        abi: NFT_MARKET_ABI,
        functionName: 'list',
        args: [nftContract as `0x${string}`, BigInt(tokenId), parseEther(price)],
      });
    } catch (error) {
      console.error('上架NFT失败:', error);
      toast({
        title: '错误',
        description: '上架NFT失败',
        variant: 'destructive',
      });
    }
  };

  // 授权代币给市场合约
  const approveToken = async () => {
    if (!price) {
      toast({
        title: '错误',
        description: '请填写价格',
        variant: 'destructive',
      });
      return;
    }

    try {
      writeContract({
        address: CONTRACTS.LOCALHOST.ERC20_TOKEN as `0x${string}`,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [CONTRACTS.LOCALHOST.NFT_MARKET, parseEther(price)],
      });
    } catch (error) {
      console.error('授权代币失败:', error);
      toast({
        title: '错误',
        description: '授权代币失败',
        variant: 'destructive',
      });
    }
  };

  // 购买NFT
  const buyNFT = async () => {
    if (!listingId) {
      toast({
        title: '错误',
        description: '请填写上架ID',
        variant: 'destructive',
      });
      return;
    }

    try {
      writeContract({
        address: CONTRACTS.LOCALHOST.NFT_MARKET as `0x${string}`,
        abi: NFT_MARKET_ABI,
        functionName: 'buyNFT',
        args: [BigInt(listingId)],
      });
    } catch (error) {
      console.error('购买NFT失败:', error);
      toast({
        title: '错误',
        description: '购买NFT失败',
        variant: 'destructive',
      });
    }
  };

  // 取消上架
  const cancelListing = async () => {
    if (!listingId) {
      toast({
        title: '错误',
        description: '请填写上架ID',
        variant: 'destructive',
      });
      return;
    }

    try {
      writeContract({
        address: CONTRACTS.LOCALHOST.NFT_MARKET as `0x${string}`,
        abi: NFT_MARKET_ABI,
        functionName: 'cancelListing',
        args: [BigInt(listingId)],
      });
    } catch (error) {
      console.error('取消上架失败:', error);
      toast({
        title: '错误',
        description: '取消上架失败',
        variant: 'destructive',
      });
    }
  };

  return (
    <Card className="glass-effect border-border/50 bg-gradient-to-br from-card/80 to-card/40 backdrop-blur-sm hover:shadow-xl transition-all duration-300">
      <CardHeader className="pb-4">
        <CardTitle className="flex items-center gap-2 text-2xl bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
          🎨 NFT市场操作演示
        </CardTitle>
        <CardDescription className="text-base text-muted-foreground">
          测试NFT市场功能，触发事件监听。请确保已部署NFT市场合约。
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-6">
        {/* 合约地址信息 */}
        <div className="p-4 bg-gradient-to-r from-primary/5 to-accent/5 border border-primary/20 rounded-xl backdrop-blur-sm">
          <h3 className="font-semibold mb-3 text-primary flex items-center gap-2">
            📋 合约地址
          </h3>
          <div className="text-sm space-y-2">
            <div className="flex flex-col gap-1">
              <span className="text-muted-foreground font-medium">NFT市场:</span>
              <code className="text-xs bg-muted/50 px-2 py-1 rounded font-mono break-all">{CONTRACTS.LOCALHOST.NFT_MARKET}</code>
            </div>
            <div className="flex flex-col gap-1">
              <span className="text-muted-foreground font-medium">ERC20代币:</span>
              <code className="text-xs bg-muted/50 px-2 py-1 rounded font-mono break-all">{CONTRACTS.LOCALHOST.ERC20_TOKEN}</code>
            </div>
          </div>
        </div>

        {/* NFT操作 */}
        <div className="space-y-4 p-4 border border-border/50 rounded-xl bg-gradient-to-br from-background/50 to-muted/20">
          <h3 className="font-semibold text-lg flex items-center gap-2 text-primary">
            🎯 1. NFT操作
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="nft-contract" className="text-sm font-medium text-foreground">NFT合约地址</Label>
              <Input
                id="nft-contract"
                placeholder="0x..."
                value={nftContract}
                onChange={(e) => setNftContract(e.target.value)}
                className="bg-background/50 border-border/50 focus:border-primary transition-colors"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="token-id" className="text-sm font-medium text-foreground">Token ID</Label>
              <Input
                id="token-id"
                placeholder="1"
                value={tokenId}
                onChange={(e) => setTokenId(e.target.value)}
                className="bg-background/50 border-border/50 focus:border-primary transition-colors"
              />
            </div>
          </div>
          <div className="flex gap-3 flex-wrap">
            <Button 
              onClick={mintNFT} 
              disabled={isPending || isConfirming}
              className="bg-gradient-to-r from-primary to-primary/80 hover:from-primary/90 hover:to-primary/70 text-primary-foreground shadow-lg hover:shadow-xl transition-all duration-300"
            >
              🎨 铸造NFT
            </Button>
            <Button 
              onClick={approveNFT} 
              disabled={isPending || isConfirming}
              variant="outline"
              className="border-primary/50 text-primary hover:bg-primary/10 transition-all duration-300"
            >
              ✅ 授权NFT给市场
            </Button>
          </div>
        </div>

        {/* 上架操作 */}
        <div className="space-y-4 p-4 border border-border/50 rounded-xl bg-gradient-to-br from-background/50 to-muted/20">
          <h3 className="font-semibold text-lg flex items-center gap-2 text-accent">
            🏷️ 2. 上架操作
          </h3>
          <div className="space-y-2">
            <Label htmlFor="price" className="text-sm font-medium text-foreground">价格 (ETH)</Label>
            <Input
              id="price"
              placeholder="0.1"
              value={price}
              onChange={(e) => setPrice(e.target.value)}
              className="bg-background/50 border-border/50 focus:border-accent transition-colors"
            />
          </div>
          <Button 
            onClick={listNFT} 
            disabled={isPending || isConfirming}
            className="bg-gradient-to-r from-accent to-accent/80 hover:from-accent/90 hover:to-accent/70 text-accent-foreground shadow-lg hover:shadow-xl transition-all duration-300 w-full"
          >
            🏪 上架NFT
          </Button>
        </div>

        {/* 购买操作 */}
        <div className="space-y-4 p-4 border border-border/50 rounded-xl bg-gradient-to-br from-background/50 to-muted/20">
          <h3 className="font-semibold text-lg flex items-center gap-2 text-success">
            💰 3. 购买操作
          </h3>
          <div className="space-y-2">
            <Label htmlFor="listing-id" className="text-sm font-medium text-foreground">上架ID</Label>
            <Input
              id="listing-id"
              placeholder="0"
              value={listingId}
              onChange={(e) => setListingId(e.target.value)}
              className="bg-background/50 border-border/50 focus:border-success transition-colors"
            />
          </div>
          <div className="flex gap-3 flex-wrap">
            <Button 
              onClick={approveToken} 
              disabled={isPending || isConfirming}
              variant="outline"
              className="border-success/50 text-success hover:bg-success/10 transition-all duration-300"
            >
              ✅ 授权代币
            </Button>
            <Button 
              onClick={buyNFT} 
              disabled={isPending || isConfirming}
              className="bg-gradient-to-r from-success to-success/80 hover:from-success/90 hover:to-success/70 text-success-foreground shadow-lg hover:shadow-xl transition-all duration-300"
            >
              🛒 购买NFT
            </Button>
            <Button 
              onClick={cancelListing} 
              disabled={isPending || isConfirming} 
              variant="outline"
              className="border-destructive/50 text-destructive hover:bg-destructive/10 transition-all duration-300"
            >
              ❌ 取消上架
            </Button>
          </div>
        </div>

        {/* 状态显示 */}
        {hash && (
          <div className="p-4 bg-gradient-to-r from-primary/10 to-accent/10 border border-primary/20 rounded-xl backdrop-blur-sm animate-fade-in">
            <div className="flex items-center gap-2 mb-2">
              <span className="text-lg">📋</span>
              <h4 className="font-semibold text-primary">交易状态</h4>
            </div>
            <div className="space-y-2">
              <div className="flex flex-col gap-1">
                <span className="text-sm text-muted-foreground">交易哈希:</span>
                <code className="text-xs bg-muted/50 px-2 py-1 rounded font-mono break-all">{hash}</code>
              </div>
              {isConfirming && (
                <div className="flex items-center gap-2 text-warning animate-pulse">
                  <div className="w-2 h-2 bg-warning rounded-full animate-bounce"></div>
                  <span className="text-sm font-medium">等待确认...</span>
                </div>
              )}
              {isConfirmed && (
                <div className="flex items-center gap-2 text-success animate-scale-in">
                  <span className="text-lg">✅</span>
                  <span className="text-sm font-medium">交易已确认!</span>
                </div>
              )}
            </div>
          </div>
        )}

        <div className="p-4 bg-gradient-to-r from-muted/20 to-muted/10 border border-border/30 rounded-xl">
          <div className="flex items-center gap-2 mb-3">
            <span className="text-lg">📖</span>
            <h4 className="font-semibold text-foreground">使用说明</h4>
          </div>
          <ol className="list-decimal list-inside space-y-2 text-sm text-muted-foreground">
            <li className="flex items-start gap-2">
              <span className="text-primary font-medium">1.</span>
              <span>首先铸造一个NFT并授权给市场合约</span>
            </li>
            <li className="flex items-start gap-2">
              <span className="text-accent font-medium">2.</span>
              <span>填写价格并上架NFT（会触发NFTListed事件）</span>
            </li>
            <li className="flex items-start gap-2">
              <span className="text-success font-medium">3.</span>
              <span>授权代币给市场合约，然后购买NFT（会触发NFTSold事件）</span>
            </li>
            <li className="flex items-start gap-2">
              <span className="text-destructive font-medium">4.</span>
              <span>或者取消上架（会触发NFTListingCancelled事件）</span>
            </li>
          </ol>
        </div>
      </CardContent>
    </Card>
  );
};

export default NFTMarketDemo;