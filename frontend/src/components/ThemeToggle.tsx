import React from 'react'
import { Moon, Sun, Monitor } from 'lucide-react'
import { Button } from './ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from './ui/dropdown-menu'
import { useTheme } from '../contexts/ThemeContext'

export function ThemeToggle() {
  const { theme, setTheme, actualTheme } = useTheme()

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button 
          variant="outline" 
          size="sm" 
          className="glass-effect border-border/50 hover:border-border hover-lift transition-all duration-300"
        >
          {actualTheme === 'dark' ? (
            <Moon className="h-4 w-4" />
          ) : (
            <Sun className="h-4 w-4" />
          )}
          <span className="sr-only">切换主题</span>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent 
        align="end" 
        className="glass-effect border-border/50 animate-fade-in"
      >
        <DropdownMenuItem 
          onClick={() => setTheme('light')}
          className={`cursor-pointer transition-colors ${
            theme === 'light' ? 'bg-accent/20 text-accent-foreground' : ''
          }`}
        >
          <Sun className="mr-2 h-4 w-4" />
          <span>浅色模式</span>
        </DropdownMenuItem>
        <DropdownMenuItem 
          onClick={() => setTheme('dark')}
          className={`cursor-pointer transition-colors ${
            theme === 'dark' ? 'bg-accent/20 text-accent-foreground' : ''
          }`}
        >
          <Moon className="mr-2 h-4 w-4" />
          <span>深色模式</span>
        </DropdownMenuItem>
        <DropdownMenuItem 
          onClick={() => setTheme('system')}
          className={`cursor-pointer transition-colors ${
            theme === 'system' ? 'bg-accent/20 text-accent-foreground' : ''
          }`}
        >
          <Monitor className="mr-2 h-4 w-4" />
          <span>跟随系统</span>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}