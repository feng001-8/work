import React, { useState, useEffect } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseEther, decodeEventLog } from 'viem';
import { TOKEN_BANK_ABI, ERC20_ABI } from '../../lib/contracts';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
import { Button } from '../ui/button';
import { Input } from '../ui/input';
import { Label } from '../ui/label';
import { useToast } from '../ui/use-toast';
import { Play, Loader2, Copy, CheckCircle } from 'lucide-react';

interface DelegateExecutorFormProps {
  tokenAddress: string;
  tokenBankAddress: string;
  onSuccess?: () => void;
}

export const DelegateExecutorForm: React.FC<DelegateExecutorFormProps> = ({ 
  tokenBankAddress, 
  tokenAddress, 
  onSuccess 
}) => {
  const { address, isConnected } = useAccount();
  const { toast } = useToast();
  const [ownerAddress, setOwnerAddress] = useState('');
  const [amount, setAmount] = useState('');
  const [deadline, setDeadline] = useState('');
  const [rValue, setRValue] = useState('');
  const [sValue, setSValue] = useState('');
  const [vValue, setVValue] = useState('');
  const [isExecuting, setIsExecuting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [createdAuthHash, setCreatedAuthHash] = useState('');
  const [copied, setCopied] = useState(false);



  const { writeContract: executeAuthorization, data: executeHash, isPending: isExecutePending, error: executeError } = useWriteContract();

  const { isLoading: isExecuteConfirming, isSuccess: isExecuteSuccess, isError: isExecuteTxError, data: executeTxData } = useWaitForTransactionReceipt({
    hash: executeHash,
  });

  // 处理执行委托存款的结果
  useEffect(() => {
    if (isExecuteSuccess && executeTxData) {
      // 设置交易哈希
      setCreatedAuthHash(executeTxData.transactionHash);
      
      toast({
        title: '委托存款执行成功！',
        description: '委托存款已成功完成，代币已存入TokenBank',
      });
      setIsExecuting(false);
      setSuccess('委托存款执行成功！代币已成功存入TokenBank。');
      
      onSuccess?.();
    } else if (executeError || isExecuteTxError) {
      toast({
        title: '委托存款执行失败',
        description: executeError?.message || '交易失败',
        variant: 'destructive',
      });
      setIsExecuting(false);
    }
  }, [isExecuteSuccess, executeTxData, executeError, isExecuteTxError, onSuccess, toast]);

  // 重置状态当交易不再pending时
  useEffect(() => {
    if (!isExecutePending && !isExecuteConfirming) {
      setIsExecuting(false);
    }
  }, [isExecutePending, isExecuteConfirming]);

  const handleExecuteAuthorization = async () => {
    if (!isConnected || !address) {
      setError('请先连接钱包');
      return;
    }

    if (!ownerAddress || !amount || !deadline || !rValue || !sValue || !vValue) {
      setError('请填写所有必填字段');
      return;
    }

    try {
      setError('');
      setSuccess('');
      setCreatedAuthHash('');
      setIsExecuting(true);

      const deadlineTimestamp = Math.floor(new Date(deadline).getTime() / 1000);
      const amountWei = parseEther(amount);
      const v = parseInt(vValue);
      const r = rValue as `0x${string}`;
      const s = sValue as `0x${string}`;

      // 调用合约执行委托存款
      executeAuthorization({
        address: tokenBankAddress as `0x${string}`,
        abi: TOKEN_BANK_ABI,
        functionName: 'delegateDepositWithPermit',
        args: [
          ownerAddress as `0x${string}`,
          address as `0x${string}`, // delegate (当前连接的钱包地址)
          amountWei,
          BigInt(deadlineTimestamp),
          v,
          r,
          s
        ],
      });

    } catch (err: any) {
      console.error('执行委托存款失败:', err);
      toast({
        title: '执行委托存款失败',
        description: err.message || '执行委托存款失败',
        variant: 'destructive',
      });
      setIsExecuting(false);
    }
  };

  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      toast({
        title: '已复制到剪贴板',
        description: '交易哈希已复制到剪贴板',
      });
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('复制失败:', err);
    }
  };

  if (!isConnected) {
    return (
      <Card className="glass-effect hover-lift">
        <CardHeader className="bg-gradient-to-r from-green-500/10 to-blue-500/10 rounded-t-lg">
          <CardTitle className="flex items-center gap-2">
            <Play className="h-5 w-5 text-green-500" />
            执行委托存款
        </CardTitle>
        <CardDescription>使用EIP-2612签名执行委托存款到区块链</CardDescription>
        </CardHeader>
        <CardContent className="p-6">
          <p className="text-muted-foreground">请先连接钱包以使用委托存款功能</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="glass-effect hover-lift">
      <CardHeader className="bg-gradient-to-r from-green-500/10 to-blue-500/10 rounded-t-lg">
        <CardTitle className="flex items-center gap-2">
          <Play className="h-5 w-5 text-green-500" />
          执行委托存款
        </CardTitle>
        <CardDescription>使用EIP-2612签名执行委托存款到区块链（需要支付gas费用）</CardDescription>
      </CardHeader>
      <CardContent className="space-y-6 p-6">
        {/* 执行委托授权 */}
        <div className="space-y-4">
          <div className="flex items-center gap-2 mb-3">
            <Play className="h-4 w-4 text-green-500" />
            <h4 className="font-medium">执行委托存款</h4>
          </div>
          
          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="owner-address">授权者地址 *</Label>
              <Input
                id="owner-address"
                type="text"
                value={ownerAddress}
                onChange={(e) => setOwnerAddress(e.target.value)}
                placeholder="0x..."
                className="font-mono"
              />
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

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="space-y-2">
                <Label htmlFor="r-value">签名 R 值 *</Label>
                <Input
                  id="r-value"
                  type="text"
                  value={rValue}
                  onChange={(e) => setRValue(e.target.value)}
                  placeholder="0x..."
                  className="font-mono text-xs"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="s-value">签名 S 值 *</Label>
                <Input
                  id="s-value"
                  type="text"
                  value={sValue}
                  onChange={(e) => setSValue(e.target.value)}
                  placeholder="0x..."
                  className="font-mono text-xs"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="v-value">恢复标识 V *</Label>
                <Input
                  id="v-value"
                  type="number"
                  value={vValue}
                  onChange={(e) => setVValue(e.target.value)}
                  placeholder="27 或 28"
                />
              </div>
            </div>

            <Button
              onClick={handleExecuteAuthorization}
              disabled={isExecuting || isExecutePending || isExecuteConfirming}
              className="w-full"
              size="lg"
            >
              {isExecuting || isExecutePending || isExecuteConfirming ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  执行中...
                </>
              ) : (
                <>
                  <Play className="h-4 w-4 mr-2" />
                  执行委托存款
                </>
              )}
            </Button>
          </div>
        </div>

        {/* 显示创建成功的授权哈希 */}
        {createdAuthHash && (
          <div className="p-4 bg-green-50 dark:bg-green-950/20 border border-green-200 dark:border-green-800 rounded-lg">
            <div className="flex items-center gap-2 mb-2">
              <CheckCircle className="h-4 w-4 text-green-600" />
              <h5 className="font-medium text-green-800 dark:text-green-200">委托存款已完成</h5>
            </div>
            <p className="text-sm text-green-700 dark:text-green-300 mb-3">
              委托存款已成功执行到区块链上，交易哈希：
            </p>
            <div className="flex items-center gap-2">
              <Input
                value={createdAuthHash}
                readOnly
                className="font-mono text-sm"
              />
              <Button
                size="sm"
                variant="outline"
                onClick={() => copyToClipboard(createdAuthHash)}
              >
                {copied ? (
                  <CheckCircle className="h-4 w-4" />
                ) : (
                  <Copy className="h-4 w-4" />
                )}
              </Button>
            </div>
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
        <div className="p-4 bg-green-50 dark:bg-green-950/20 border border-green-200 dark:border-green-800 rounded-lg">
          <h5 className="font-medium text-green-800 dark:text-green-200 mb-2">使用说明</h5>
          <div className="text-sm text-green-700 dark:text-green-300 space-y-1">
            <p>1. 从授权者获取EIP-2612签名数据（R、S、V值等）</p>
            <p>2. 填写授权者地址、存款金额、截止时间和签名数据</p>
            <p>3. 点击"执行委托存款"按钮（您将支付gas费用）</p>
            <p>4. 交易确认后，将代表授权者完成存款到TokenBank</p>
          </div>
        </div>
      </CardContent>
    </Card>
  );
};

export default DelegateExecutorForm;