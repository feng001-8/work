import React, { useEffect, useRef } from 'react'

interface FloatingElement {
  id: number
  x: number
  y: number
  vx: number
  vy: number
  size: number
  rotation: number
  rotationSpeed: number
  opacity: number
  color: string
  shape: 'circle' | 'triangle' | 'square' | 'hexagon'
  pulsePhase: number
}

interface FloatingElementsProps {
  elementCount?: number
  className?: string
  colors?: string[]
  interactive?: boolean
}

const FloatingElements: React.FC<FloatingElementsProps> = ({
  elementCount = 15,
  className = '',
  colors = ['#3b82f6', '#8b5cf6', '#06b6d4', '#10b981', '#f59e0b', '#ef4444'],
  interactive = true
}) => {
  const containerRef = useRef<HTMLDivElement>(null)
  const elementsRef = useRef<FloatingElement[]>([])
  const animationRef = useRef<number>()
  const mouseRef = useRef({ x: 0, y: 0 })

  useEffect(() => {
    const container = containerRef.current
    if (!container) return

    const shapes: FloatingElement['shape'][] = ['circle', 'triangle', 'square', 'hexagon']

    const createFloatingElement = (id: number): FloatingElement => {
      return {
        id,
        x: Math.random() * container.offsetWidth,
        y: Math.random() * container.offsetHeight,
        vx: (Math.random() - 0.5) * 0.3,
        vy: (Math.random() - 0.5) * 0.3,
        size: Math.random() * 30 + 10,
        rotation: Math.random() * 360,
        rotationSpeed: (Math.random() - 0.5) * 2,
        opacity: Math.random() * 0.4 + 0.1,
        color: colors[Math.floor(Math.random() * colors.length)],
        shape: shapes[Math.floor(Math.random() * shapes.length)],
        pulsePhase: Math.random() * Math.PI * 2
      }
    }

    const initElements = () => {
      elementsRef.current = []
      for (let i = 0; i < elementCount; i++) {
        elementsRef.current.push(createFloatingElement(i))
      }
    }

    const updateElement = (element: FloatingElement) => {
      // 基础移动
      element.x += element.vx
      element.y += element.vy
      element.rotation += element.rotationSpeed
      element.pulsePhase += 0.02

      // 边界处理 - 循环
      if (element.x < -element.size) element.x = container.offsetWidth + element.size
      if (element.x > container.offsetWidth + element.size) element.x = -element.size
      if (element.y < -element.size) element.y = container.offsetHeight + element.size
      if (element.y > container.offsetHeight + element.size) element.y = -element.size

      // 鼠标交互
      if (interactive) {
        const dx = mouseRef.current.x - element.x
        const dy = mouseRef.current.y - element.y
        const distance = Math.sqrt(dx * dx + dy * dy)
        const maxDistance = 150

        if (distance < maxDistance) {
          const force = (maxDistance - distance) / maxDistance * 0.01
          const angle = Math.atan2(dy, dx)
          element.vx -= Math.cos(angle) * force
          element.vy -= Math.sin(angle) * force
          element.rotationSpeed += force * 10
        }
      }

      // 脉冲效果
      const pulse = Math.sin(element.pulsePhase) * 0.2 + 1
      element.opacity = (Math.sin(element.pulsePhase * 0.5) * 0.2 + 0.3) * pulse
    }

    const renderElements = () => {
      // 清除现有元素
      const existingElements = container.querySelectorAll('.floating-element')
      existingElements.forEach(el => el.remove())

      // 渲染新元素
      elementsRef.current.forEach(element => {
        const div = document.createElement('div')
        div.className = 'floating-element absolute pointer-events-none'
        div.style.left = `${element.x - element.size / 2}px`
        div.style.top = `${element.y - element.size / 2}px`
        div.style.width = `${element.size}px`
        div.style.height = `${element.size}px`
        div.style.opacity = element.opacity.toString()
        div.style.transform = `rotate(${element.rotation}deg)`
        div.style.transition = 'all 0.1s ease-out'

        // 根据形状创建不同的样式
        const pulse = Math.sin(element.pulsePhase) * 0.3 + 1
        const currentSize = element.size * pulse

        switch (element.shape) {
          case 'circle':
            div.style.borderRadius = '50%'
            div.style.background = `radial-gradient(circle, ${element.color}40, ${element.color}10)`
            div.style.border = `1px solid ${element.color}60`
            break
          case 'triangle':
            div.style.width = '0'
            div.style.height = '0'
            div.style.borderLeft = `${currentSize / 2}px solid transparent`
            div.style.borderRight = `${currentSize / 2}px solid transparent`
            div.style.borderBottom = `${currentSize}px solid ${element.color}40`
            div.style.filter = `drop-shadow(0 0 8px ${element.color}30)`
            break
          case 'square':
            div.style.background = `linear-gradient(45deg, ${element.color}40, ${element.color}10)`
            div.style.border = `1px solid ${element.color}60`
            div.style.borderRadius = '4px'
            break
          case 'hexagon':
            div.style.background = element.color + '40'
            div.style.clipPath = 'polygon(50% 0%, 100% 25%, 100% 75%, 50% 100%, 0% 75%, 0% 25%)'
            div.style.filter = `drop-shadow(0 0 6px ${element.color}30)`
            break
        }

        container.appendChild(div)
      })
    }

    const animate = () => {
      elementsRef.current.forEach(updateElement)
      renderElements()
      animationRef.current = requestAnimationFrame(animate)
    }

    const handleMouseMove = (e: MouseEvent) => {
      const rect = container.getBoundingClientRect()
      mouseRef.current = {
        x: e.clientX - rect.left,
        y: e.clientY - rect.top
      }
    }

    const handleResize = () => {
      initElements()
    }

    // 初始化
    initElements()
    animate()

    // 事件监听
    if (interactive) {
      container.addEventListener('mousemove', handleMouseMove)
    }
    window.addEventListener('resize', handleResize)

    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current)
      }
      if (interactive) {
        container.removeEventListener('mousemove', handleMouseMove)
      }
      window.removeEventListener('resize', handleResize)
    }
  }, [elementCount, colors, interactive])

  return (
    <div
      ref={containerRef}
      className={`absolute inset-0 overflow-hidden pointer-events-none ${className}`}
      style={{
        zIndex: 1
      }}
    />
  )
}

export default FloatingElements