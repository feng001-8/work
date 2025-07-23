import { useState } from 'react'
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts'
import { Key, Eye, EyeOff, Copy } from 'lucide-react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card'
import { Button } from '../ui/button'
import { Input } from '../ui/input'
import { Label } from '../ui/label'
import { useToast } from '../ui/use-toast'

export interface GeneratedWallet {
  privateKey: string
  address: string
  account: any
}

interface PrivateKeyGeneratorProps {
  onWalletGenerated?: (wallet: GeneratedWallet) => void
}

export function PrivateKeyGenerator({ onWalletGenerated }: PrivateKeyGeneratorProps) {
  const [generatedWallet, setGeneratedWallet] = useState<GeneratedWallet | null>(null)
  const [showPrivateKey, setShowPrivateKey] = useState(false)
  const { toast } = useToast()

  // 生成新钱包
  const generateWallet = () => {
    try {
      const privateKey = generatePrivateKey()
      const account = privateKeyToAccount(privateKey)
      
      const wallet: GeneratedWallet = {
        privateKey,
        address: account.address,
        account
      }
      
      setGeneratedWallet(wallet)
      onWalletGenerated?.(wallet)
      
      toast({
        title: "钱包生成成功",
        description: "新的钱包地址已生成，请妥善保管私钥",
      })
    } catch (error) {
      toast({
        title: "生成失败",
        description: "钱包生成过程中出现错误",
        variant: "destructive",
      })
    }
  }

  // 复制到剪贴板
  const copyToClipboard = async (text: string, label: string) => {
    try {
      await navigator.clipboard.writeText(text)
      toast({
        title: "复制成功",
        description: `${label}已复制到剪贴板`,
      })
    } catch (error) {
      toast({
        title: "复制失败",
        description: "无法复制到剪贴板",
        variant: "destructive",
      })
    }
  }

  return (
    <Card className="glass-effect hover-lift animate-scale-in">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Key className="h-5 w-5 text-primary" />
          生成私钥
        </CardTitle>
        <CardDescription>
          生成新的以太坊钱包私钥和地址
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <Button 
          onClick={generateWallet} 
          className="w-full"
          size="lg"
        >
          <Key className="h-4 w-4 mr-2" />
          生成新钱包
        </Button>
        
        {generatedWallet && (
          <div className="space-y-4 animate-slide-up">
            <div className="space-y-2">
              <Label className="text-sm font-semibold">钱包地址</Label>
              <div className="flex items-center gap-2">
                <Input 
                  value={generatedWallet.address} 
                  readOnly 
                  className="font-mono text-xs"
                />
                <Button 
                  size="sm" 
                  variant="outline"
                  onClick={() => copyToClipboard(generatedWallet.address, '地址')}
                >
                  <Copy className="h-3 w-3" />
                </Button>
              </div>
            </div>
            
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <Label className="text-sm font-semibold">私钥</Label>
                <Button 
                  size="sm" 
                  variant="ghost"
                  onClick={() => setShowPrivateKey(!showPrivateKey)}
                >
                  {showPrivateKey ? <EyeOff className="h-3 w-3" /> : <Eye className="h-3 w-3" />}
                </Button>
              </div>
              <div className="flex items-center gap-2">
                <Input 
                  type={showPrivateKey ? 'text' : 'password'}
                  value={generatedWallet.privateKey} 
                  readOnly 
                  className="font-mono text-xs"
                />
                <Button 
                  size="sm" 
                  variant="outline"
                  onClick={() => copyToClipboard(generatedWallet.privateKey, '私钥')}
                >
                  <Copy className="h-3 w-3" />
                </Button>
              </div>
              <p className="text-xs text-muted-foreground">
                ⚠️ 请妥善保管私钥，不要泄露给他人
              </p>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  )
}