import React, { useState, useEffect } from 'react';
import { useAccount, useReadContract, useChainId, useSignTypedData } from 'wagmi';
import { parseEther, keccak256, toHex } from 'viem';
import { ERC20_ABI } from '../../lib/contracts';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
import { Button } from '../ui/button';
import { Input } from '../ui/input';
import { Label } from '../ui/label';
import { useToast } from '../ui/use-toast';
import { formatEther as formatEtherUtil } from '../../lib/utils';
import { Users, Loader2, Shield, Copy, Eye, EyeOff } from 'lucide-react';

interface DelegateAuthorizationFormProps {
  tokenAddress: string;
  tokenBankAddress: string;
}

interface SignatureDetails {
  r: string;
  s: string;
  v: number;
  domainSeparatorHash: string;
  messageHash: string;
  typedDataHash: string;
  fullSignature: string;
}

export const DelegateAuthorizationForm: React.FC<DelegateAuthorizationFormProps> = ({ 
  tokenBankAddress, 
  tokenAddress
}) => {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { toast } = useToast();
  const [delegateAddress, setDelegateAddress] = useState('');
  const [amount, setAmount] = useState('');
  const [deadline, setDeadline] = useState('');
  const [isCreating, setIsCreating] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [copied, setCopied] = useState(false);
  const [signatureDetails, setSignatureDetails] = useState<SignatureDetails | null>(null);
  const [showTechnicalDetails, setShowTechnicalDetails] = useState(false);

  // 获取代币余额
  const { data: tokenBalance } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [address as `0x${string}`],
    query: { enabled: !!address }
  });

  // 获取代币名称
  const { data: tokenName } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'name',
  });

  // 获取nonces
  const { data: nonces } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'nonces',
    args: [address as `0x${string}`],
    query: { enabled: !!address }
  });

  const { signTypedData, data: signatureData, isPending: isSignPending, error: signError } = useSignTypedData();

  // 处理签名完成后的逻辑
  useEffect(() => {
    if (signatureData && !isSignPending) {
      // 签名完成，解析签名数据
      try {
        const signature = signatureData;
        const r = signature.slice(0, 66) as `0x${string}`;
        const s = ('0x' + signature.slice(66, 130)) as `0x${string}`;
        const v = parseInt(signature.slice(130, 132), 16);

        // 获取当前的表单数据
        const deadlineTimestamp = Math.floor(new Date(deadline).getTime() / 1000);
        const amountWei = parseEther(amount);

        // 计算签名技术细节
        const domain = {
          name: tokenName as string,
          version: '1',
          chainId: chainId,
          verifyingContract: tokenAddress as `0x${string}`,
        };

        const types = {
          Permit: [
            { name: 'owner', type: 'address' },
            { name: 'spender', type: 'address' },
            { name: 'value', type: 'uint256' },
            { name: 'nonce', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
          ],
        };

        const message = {
          owner: address,
          spender: tokenBankAddress as `0x${string}`,
          value: amountWei,
          nonce: nonces as bigint,
          deadline: BigInt(deadlineTimestamp),
        };

        // 计算域分隔符哈希
        const domainTypeHash = keccak256(toHex('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'));
        const nameHash = keccak256(toHex(domain.name));
        const versionHash = keccak256(toHex(domain.version));
        const domainSeparatorHash = keccak256(
          `0x${domainTypeHash.slice(2)}${nameHash.slice(2)}${versionHash.slice(2)}${chainId.toString(16).padStart(64, '0')}${domain.verifyingContract.slice(2).padStart(64, '0')}`
        );

        // 计算消息哈希
         const permitTypeHash = keccak256(toHex('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'));
         const messageHash = keccak256(
           `0x${permitTypeHash.slice(2)}${(message.owner as string).slice(2).padStart(64, '0')}${(message.spender as string).slice(2).padStart(64, '0')}${message.value.toString(16).padStart(64, '0')}${message.nonce.toString(16).padStart(64, '0')}${message.deadline.toString(16).padStart(64, '0')}`
         );

        // 计算最终的 TypedData 哈希
        const typedDataHash = keccak256(
          `0x1901${domainSeparatorHash.slice(2)}${messageHash.slice(2)}`
        );

        // 存储签名技术细节
        setSignatureDetails({
          r,
          s,
          v,
          domainSeparatorHash,
          messageHash,
          typedDataHash,
          fullSignature: signature,
        });
        
        // 自动显示技术细节
        setShowTechnicalDetails(true);
        
        // 显示签名成功消息
        toast({
          title: '签名创建成功！',
          description: '您的EIP-2612签名已生成，请将签名数据发送给委托人',
        });
        
        setIsCreating(false);
        setSuccess('EIP-2612签名已生成！请将以下签名数据发送给委托人执行存款。');
        
      } catch (err: any) {
        console.error('处理签名失败:', err);
        toast({
          title: '处理签名失败',
          description: err.message || '处理签名失败',
          variant: 'destructive',
        });
        setIsCreating(false);
      }
    } else if (signError) {
      toast({
        title: '签名失败',
        description: signError.message || '用户取消签名',
        variant: 'destructive',
      });
      setIsCreating(false);
    }
  }, [signatureData, isSignPending, signError, deadline, amount, delegateAddress, toast, address, tokenName, chainId, tokenAddress, nonces]);

  // 重置状态当签名不再pending时
  useEffect(() => {
    if (!isSignPending) {
      // 签名完成后不自动重置isCreating，让用户看到结果
    }
  }, [isSignPending]);

  const handleCreateAuthorization = async () => {
    if (!isConnected || !address) {
      setError('请先连接钱包');
      return;
    }

    if (!delegateAddress || !amount || !deadline) {
      setError('请填写所有必填字段');
      return;
    }

    try {
      setError('');
      setSuccess('');
      setIsCreating(true);

      const deadlineTimestamp = Math.floor(new Date(deadline).getTime() / 1000);
      const amountWei = parseEther(amount);

      // 构建EIP-2612签名数据
      const domain = {
        name: tokenName as string,
        version: '1',
        chainId: chainId,
        verifyingContract: tokenAddress as `0x${string}`,
      };

      const types = {
        Permit: [
          { name: 'owner', type: 'address' },
          { name: 'spender', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'nonce', type: 'uint256' },
          { name: 'deadline', type: 'uint256' },
        ],
      };

      const message = {
        owner: address,
        spender: tokenBankAddress as `0x${string}`,
        value: amountWei,
        nonce: nonces as bigint,
        deadline: BigInt(deadlineTimestamp),
      };

      // 使用 wagmi 的 signTypedData
      signTypedData({
        domain,
        types,
        primaryType: 'Permit',
        message
      });

    } catch (err: any) {
      console.error('创建委托授权失败:', err);
      toast({
        title: '创建委托授权失败',
        description: err.message || '创建委托授权失败',
        variant: 'destructive',
      });
      setIsCreating(false);
    }
  };



  const copySignatureDetail = async (text: string, description: string) => {
    try {
      await navigator.clipboard.writeText(text);
      toast({
        title: '已复制到剪贴板',
        description,
      });
    } catch (err) {
      console.error('复制失败:', err);
    }
  };

  if (!isConnected) {
    return (
      <Card className="glass-effect hover-lift">
        <CardHeader className="bg-gradient-to-r from-blue-500/10 to-purple-500/10 rounded-t-lg">
          <CardTitle className="flex items-center gap-2">
            <Users className="h-5 w-5 text-blue-500" />
            创建委托授权
          </CardTitle>
          <CardDescription>创建委托授权，让其他人代为执行存款</CardDescription>
        </CardHeader>
        <CardContent className="p-6">
          <p className="text-muted-foreground">请先连接钱包以使用委托授权功能</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="glass-effect hover-lift">
      <CardHeader className="bg-gradient-to-r from-blue-500/10 to-purple-500/10 rounded-t-lg">
        <CardTitle className="flex items-center gap-2">
          <Users className="h-5 w-5 text-blue-500" />
          生成EIP-2612签名
        </CardTitle>
        <CardDescription>生成离线签名，授权他人代为执行存款（您无需支付gas费用）</CardDescription>
      </CardHeader>
      <CardContent className="space-y-6 p-6">
        {/* 余额显示 */}
        <div className="p-4 bg-secondary/30 rounded-lg border border-border/50">
          <div className="flex items-center gap-2 mb-2">
            <Shield className="h-4 w-4 text-primary" />
            <span className="text-sm font-medium">代币余额</span>
          </div>
          <p className="text-lg font-semibold">
            {tokenBalance ? formatEtherUtil(tokenBalance as bigint) : '0'} {tokenName || 'MTK'}
          </p>
        </div>

        {/* 生成EIP-2612签名 */}
        <div className="space-y-4">
          <div className="flex items-center gap-2 mb-3">
            <Shield className="h-4 w-4 text-blue-500" />
            <h4 className="font-medium">生成EIP-2612签名</h4>
          </div>
          
          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="delegate-address">执行者地址 *</Label>
              <Input
                id="delegate-address"
                type="text"
                value={delegateAddress}
                onChange={(e) => setDelegateAddress(e.target.value)}
                placeholder="0x..."
                className="font-mono"
              />
              <p className="text-xs text-muted-foreground">
                输入将代为执行充值操作的地址（该地址需要有 ETH 支付 Gas 费用）
              </p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="amount">授权金额 *</Label>
              <Input
                id="amount"
                type="number"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="0.0"
                step="0.01"
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="deadline">截止时间 *</Label>
              <div className="flex gap-2">
                <Input
                  id="deadline"
                  type="datetime-local"
                  value={deadline}
                  onChange={(e) => setDeadline(e.target.value)}
                  className="flex-1"
                />
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    const now = new Date();
                    now.setMinutes(now.getMinutes() + 10);
                    const localDateTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000)
                      .toISOString()
                      .slice(0, 16);
                    setDeadline(localDateTime);
                  }}
                  className="whitespace-nowrap"
                >
                  +10分钟
                </Button>
              </div>
            </div>

            <Button
              onClick={handleCreateAuthorization}
              disabled={isCreating || isSignPending}
              className="w-full"
              size="lg"
            >
              {isCreating || isSignPending ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  {isSignPending ? '签名中...' : '处理中...'}
                </>
              ) : (
                <>
                  <Shield className="h-4 w-4 mr-2" />
                  生成EIP-2612签名
                </>
              )}
            </Button>
          </div>
        </div>

        {/* EIP-712 签名技术细节学习面板 */}
        {!signatureDetails && (
          <div className="p-4 bg-blue-50 dark:bg-blue-950/20 border border-blue-200 dark:border-blue-800 rounded-lg">
            <div className="flex items-center gap-2 mb-2">
              <Shield className="h-4 w-4 text-blue-600" />
              <h5 className="font-medium text-blue-800 dark:text-blue-200">EIP-712 签名学习</h5>
            </div>
            <p className="text-sm text-blue-700 dark:text-blue-300">
              完成签名后，您将看到 EIP-712 签名的技术细节，包括 R、S、V 值、域分隔符哈希、消息哈希等，帮助您理解椭圆曲线数字签名算法和合约验证过程。
            </p>
          </div>
        )}

        {/* EIP-712 签名技术细节展示 */}
        {signatureDetails && (
          <div className="p-4 bg-purple-50 dark:bg-purple-950/20 border border-purple-200 dark:border-purple-800 rounded-lg">
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <Shield className="h-4 w-4 text-purple-600" />
                <h5 className="font-medium text-purple-800 dark:text-purple-200">EIP-712 签名技术细节</h5>
              </div>
              <Button
                size="sm"
                variant="ghost"
                onClick={() => setShowTechnicalDetails(!showTechnicalDetails)}
              >
                {showTechnicalDetails ? (
                  <EyeOff className="h-4 w-4" />
                ) : (
                  <Eye className="h-4 w-4" />
                )}
                {showTechnicalDetails ? '隐藏' : '显示'}
              </Button>
            </div>
            
            {showTechnicalDetails && (
              <div className="space-y-3">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-medium text-purple-700 dark:text-purple-300">签名 R 值</span>
                      <Button
                        size="sm"
                        variant="ghost"
                        className="h-6 w-6 p-0"
                        onClick={() => copySignatureDetail(signatureDetails.r, 'R 值已复制')}
                      >
                        <Copy className="h-3 w-3" />
                      </Button>
                    </div>
                    <p className="text-xs font-mono bg-white dark:bg-gray-800 p-2 rounded border break-all">
                      {signatureDetails.r}
                    </p>
                  </div>
                  
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-medium text-purple-700 dark:text-purple-300">签名 S 值</span>
                      <Button
                        size="sm"
                        variant="ghost"
                        className="h-6 w-6 p-0"
                        onClick={() => copySignatureDetail(signatureDetails.s, 'S 值已复制')}
                      >
                        <Copy className="h-3 w-3" />
                      </Button>
                    </div>
                    <p className="text-xs font-mono bg-white dark:bg-gray-800 p-2 rounded border break-all">
                      {signatureDetails.s}
                    </p>
                  </div>
                  
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-medium text-purple-700 dark:text-purple-300">恢复标识 V</span>
                      <Button
                        size="sm"
                        variant="ghost"
                        className="h-6 w-6 p-0"
                        onClick={() => copySignatureDetail(signatureDetails.v.toString(), 'V 值已复制')}
                      >
                        <Copy className="h-3 w-3" />
                      </Button>
                    </div>
                    <p className="text-xs font-mono bg-white dark:bg-gray-800 p-2 rounded border">
                      {signatureDetails.v}
                    </p>
                  </div>
                  
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-medium text-purple-700 dark:text-purple-300">域分隔符哈希</span>
                      <Button
                        size="sm"
                        variant="ghost"
                        className="h-6 w-6 p-0"
                        onClick={() => copySignatureDetail(signatureDetails.domainSeparatorHash, '域分隔符哈希已复制')}
                      >
                        <Copy className="h-3 w-3" />
                      </Button>
                    </div>
                    <p className="text-xs font-mono bg-white dark:bg-gray-800 p-2 rounded border break-all">
                      {signatureDetails.domainSeparatorHash}
                    </p>
                  </div>
                  
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-medium text-purple-700 dark:text-purple-300">消息哈希</span>
                      <Button
                        size="sm"
                        variant="ghost"
                        className="h-6 w-6 p-0"
                        onClick={() => copySignatureDetail(signatureDetails.messageHash, '消息哈希已复制')}
                      >
                        <Copy className="h-3 w-3" />
                      </Button>
                    </div>
                    <p className="text-xs font-mono bg-white dark:bg-gray-800 p-2 rounded border break-all">
                      {signatureDetails.messageHash}
                    </p>
                  </div>
                  
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-medium text-purple-700 dark:text-purple-300">TypedData 哈希</span>
                      <Button
                        size="sm"
                        variant="ghost"
                        className="h-6 w-6 p-0"
                        onClick={() => copySignatureDetail(signatureDetails.typedDataHash, 'TypedData 哈希已复制')}
                      >
                        <Copy className="h-3 w-3" />
                      </Button>
                    </div>
                    <p className="text-xs font-mono bg-white dark:bg-gray-800 p-2 rounded border break-all">
                      {signatureDetails.typedDataHash}
                    </p>
                  </div>
                </div>
                
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-medium text-purple-700 dark:text-purple-300">完整签名</span>
                    <Button
                      size="sm"
                      variant="ghost"
                      className="h-6 w-6 p-0"
                      onClick={() => copySignatureDetail(signatureDetails.fullSignature, '完整签名已复制')}
                    >
                      <Copy className="h-3 w-3" />
                    </Button>
                  </div>
                  <p className="text-xs font-mono bg-white dark:bg-gray-800 p-2 rounded border break-all">
                    {signatureDetails.fullSignature}
                  </p>
                </div>
                
                <div className="mt-4 p-3 bg-gray-50 dark:bg-gray-800 rounded border">
                  <h6 className="text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">合约验证过程</h6>
                  <div className="text-xs text-gray-600 dark:text-gray-400 space-y-1">
                    <p>1. 合约使用 ecrecover(typedDataHash, v, r, s) 恢复签名者地址</p>
                    <p>2. 验证恢复的地址是否与授权者地址匹配</p>
                    <p>3. 检查 nonce 是否正确且未被使用</p>
                    <p>4. 验证截止时间是否有效</p>
                    <p>5. 执行委托授权逻辑</p>
                  </div>
                </div>
              </div>
            )}
          </div>
        )}



        {/* 错误和成功消息 */}
        {error && (
          <div className="p-4 bg-destructive/10 border border-destructive/20 rounded-lg">
            <p className="text-destructive text-sm">{error}</p>
          </div>
        )}
        
        {success && (
          <div className="p-4 bg-green-50 dark:bg-green-950/20 border border-green-200 dark:border-green-800 rounded-lg">
            <p className="text-green-700 dark:text-green-300 text-sm">{success}</p>
          </div>
        )}

        {/* 使用说明 */}
        <div className="p-4 bg-blue-50 dark:bg-blue-950/20 border border-blue-200 dark:border-blue-800 rounded-lg">
          <h5 className="font-medium text-blue-800 dark:text-blue-200 mb-2">使用说明</h5>
          <div className="text-sm text-blue-700 dark:text-blue-300 space-y-1">
            <p>1. 填写委托人地址、授权金额和截止时间</p>
            <p>2. 点击"生成EIP-2612签名"按钮并签名（免费，无gas费用）</p>
            <p>3. 将生成的签名数据（R、S、V值等）发送给委托人</p>
            <p>4. 委托人使用签名数据执行链上存款操作（委托人支付gas费用）</p>
          </div>
        </div>
      </CardContent>
    </Card>
  );
};

export default DelegateAuthorizationForm;