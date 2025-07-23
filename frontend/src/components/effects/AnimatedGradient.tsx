import React, { useEffect, useRef } from 'react'

interface AnimatedGradientProps {
  className?: string
  colors?: string[]
  speed?: number
  blur?: boolean
}

const AnimatedGradient: React.FC<AnimatedGradientProps> = ({
  className = '',
  colors = [
    '#3b82f6', // blue-500
    '#8b5cf6', // violet-500
    '#06b6d4', // cyan-500
    '#10b981', // emerald-500
    '#f59e0b', // amber-500
    '#ef4444', // red-500
    '#ec4899', // pink-500
    '#6366f1'  // indigo-500
  ],
  speed = 1,
  blur = true
}) => {
  const containerRef = useRef<HTMLDivElement>(null)
  const animationRef = useRef<number>()
  const timeRef = useRef(0)

  useEffect(() => {
    const container = containerRef.current
    if (!container) return

    const animate = () => {
      timeRef.current += 0.01 * speed
      
      // 创建动态渐变
      const gradientStops = colors.map((color, index) => {
        const angle = (timeRef.current + index * (Math.PI * 2 / colors.length)) % (Math.PI * 2)
        const x = 50 + Math.cos(angle) * 30
        const y = 50 + Math.sin(angle) * 30
        const opacity = (Math.sin(timeRef.current * 2 + index) + 1) * 0.3 + 0.1
        return `${color}${Math.floor(opacity * 255).toString(16).padStart(2, '0')} ${x}% ${y}%`
      }).join(', ')

      // 应用渐变
      container.style.background = `radial-gradient(circle at center, ${gradientStops})`
      
      // 添加动态变换
      const scale = 1 + Math.sin(timeRef.current * 0.5) * 0.1
      const rotate = timeRef.current * 10
      container.style.transform = `scale(${scale}) rotate(${rotate}deg)`
      
      animationRef.current = requestAnimationFrame(animate)
    }

    animate()

    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current)
      }
    }
  }, [colors, speed])

  return (
    <div
      ref={containerRef}
      className={`absolute inset-0 ${blur ? 'blur-3xl' : ''} ${className}`}
      style={{
        zIndex: -1,
        opacity: 0.6,
        transformOrigin: 'center',
        transition: 'opacity 0.3s ease'
      }}
    />
  )
}

export default AnimatedGradient