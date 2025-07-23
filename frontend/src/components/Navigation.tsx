import React from 'react'
import { Link, useLocation } from 'react-router-dom'
import { Coins, ShoppingBag, Sparkles, Wallet } from 'lucide-react'
import { Button } from './ui/button'
import { ThemeToggle } from './theme/ThemeToggle'

const Navigation: React.FC = () => {
  const location = useLocation()

  return (
    <nav className="glass-effect border-b backdrop-blur-md sticky top-0 z-50 animate-fade-in">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          {/* Logo区域 */}
          <div className="flex items-center gap-3 hover-lift">
            <div className="relative">
              <div className="absolute inset-0 gradient-primary rounded-lg blur-sm opacity-75 animate-pulse-glow"></div>
              <div className="relative bg-primary rounded-lg p-2">
                <Sparkles className="h-6 w-6 text-primary-foreground" />
              </div>
            </div>
            <div className="flex flex-col">
              <span className="text-xl font-bold bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
                DApp Platform
              </span>
              <span className="text-xs text-muted-foreground font-medium">
                Web3 生态系统
              </span>
            </div>
          </div>
          
          {/* 导航按钮 */}
          <div className="flex items-center gap-2">
            <ThemeToggle />
            <Link to="/tokenbank">
              <Button 
                variant={location.pathname === '/tokenbank' ? 'default' : 'ghost'}
                className={`
                  flex items-center gap-2 transition-all duration-300 hover-lift
                  ${location.pathname === '/tokenbank' 
                    ? 'gradient-primary text-white shadow-glow' 
                    : 'hover:bg-secondary/50'
                  }
                `}
              >
                <Coins className="h-4 w-4" />
                <span className="font-medium">TokenBank</span>
              </Button>
            </Link>
            
            <Link to="/nft-market">
              <Button 
                variant={location.pathname === '/nft-market' ? 'default' : 'ghost'}
                className={`
                  flex items-center gap-2 transition-all duration-300 hover-lift
                  ${location.pathname === '/nft-market' 
                    ? 'gradient-primary text-white shadow-glow' 
                    : 'hover:bg-secondary/50'
                  }
                `}
              >
                <ShoppingBag className="h-4 w-4" />
                <span className="font-medium">NFT 市场</span>
              </Button>
            </Link>
            
            <Link to="/wallet">
              <Button 
                variant={location.pathname === '/wallet' ? 'default' : 'ghost'}
                className={`
                  flex items-center gap-2 transition-all duration-300 hover-lift
                  ${location.pathname === '/wallet' 
                    ? 'gradient-primary text-white shadow-glow' 
                    : 'hover:bg-secondary/50'
                  }
                `}
              >
                <Wallet className="h-4 w-4" />
                <span className="font-medium">钱包</span>
              </Button>
            </Link>
          </div>
        </div>
      </div>
      
      {/* 底部装饰线 */}
      <div className="h-0.5 bg-gradient-to-r from-transparent via-primary to-transparent opacity-50"></div>
    </nav>
  )
}

export default Navigation