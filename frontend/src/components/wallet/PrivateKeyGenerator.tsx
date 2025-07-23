import { useState } from 'react'
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts'
import { Key, Eye, EyeOff, Copy, Sparkles, Shield } from 'lucide-react'
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
    <Card className="glass-effect-strong hover-lift border-border/30 shadow-glow-purple">
      <CardHeader className="pb-6">
        <CardTitle className="flex items-center gap-3 text-xl">
          <div className="relative">
            <div className="absolute inset-0 animate-pulse-glow rounded-full"></div>
            <Key className="h-6 w-6 text-gradient relative z-10" />
            <Sparkles className="h-3 w-3 text-trae-purple absolute -top-1 -right-1 animate-bounce-gentle" />
          </div>
          <span className="text-gradient">量子密钥生成器</span>
        </CardTitle>
        <CardDescription className="text-foreground/70 text-base">
          使用量子级加密算法生成安全的以太坊钱包
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-6">
        <Button 
          onClick={generateWallet} 
          className="w-full gradient-trae hover-glow text-white font-semibold py-4 text-lg shadow-glow"
          size="lg"
        >
          <Sparkles className="h-5 w-5 mr-3 animate-pulse-glow" />
          生成量子钱包
          <Shield className="h-5 w-5 ml-3" />
        </Button>
        
        {generatedWallet && (
          <div className="space-y-6 animate-slide-up">
            <div className="glass-effect p-4 rounded-xl border border-border/20">
              <div className="space-y-3">
                <Label className="text-base font-semibold flex items-center gap-2">
                  <div className="w-2 h-2 bg-trae-cyan rounded-full animate-pulse-glow"></div>
                  钱包地址
                </Label>
                <div className="flex items-center gap-3">
                  <Input 
                    value={generatedWallet.address} 
                    readOnly 
                    className="font-mono text-sm glass-effect border-border/30 bg-card/50"
                  />
                  <Button 
                    size="sm" 
                    variant="outline"
                    className="glass-effect hover-glow border-border/30"
                    onClick={() => copyToClipboard(generatedWallet.address, '地址')}
                  >
                    <Copy className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            </div>
            
            <div className="glass-effect p-4 rounded-xl border border-border/20">
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <Label className="text-base font-semibold flex items-center gap-2">
                    <div className="w-2 h-2 bg-trae-pink rounded-full animate-pulse-glow"></div>
                    量子私钥
                  </Label>
                  <Button 
                    size="sm" 
                    variant="ghost"
                    className="glass-effect hover-glow"
                    onClick={() => setShowPrivateKey(!showPrivateKey)}
                  >
                    {showPrivateKey ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                  </Button>
                </div>
                <div className="flex items-center gap-3">
                  <Input 
                    type={showPrivateKey ? 'text' : 'password'}
                    value={generatedWallet.privateKey} 
                    readOnly 
                    className="font-mono text-sm glass-effect border-border/30 bg-card/50"
                  />
                  <Button 
                    size="sm" 
                    variant="outline"
                    className="glass-effect hover-glow border-border/30"
                    onClick={() => copyToClipboard(generatedWallet.privateKey, '私钥')}
                  >
                    <Copy className="h-4 w-4" />
                  </Button>
                </div>
                <div className="flex items-center gap-2 p-3 rounded-lg bg-destructive/10 border border-destructive/20">
                  <Shield className="h-4 w-4 text-destructive" />
                  <p className="text-sm text-destructive font-medium">
                    量子级安全提醒：请将私钥存储在安全的离线环境中
                  </p>
                </div>
              </div>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  )
}