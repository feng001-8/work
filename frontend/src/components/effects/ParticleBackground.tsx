import React, { useEffect, useRef } from 'react'

interface Particle {
  x: number
  y: number
  vx: number
  vy: number
  size: number
  opacity: number
  color: string
  life: number
  maxLife: number
}

interface ParticleBackgroundProps {
  particleCount?: number
  interactive?: boolean
  className?: string
  colors?: string[]
}

const ParticleBackground: React.FC<ParticleBackgroundProps> = ({
  particleCount = 80,
  interactive = true,
  className = '',
  colors = ['#3b82f6', '#8b5cf6', '#06b6d4', '#10b981', '#f59e0b']
}) => {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const animationRef = useRef<number>()
  const particlesRef = useRef<Particle[]>([])
  const mouseRef = useRef({ x: 0, y: 0 })
  const isMouseInCanvasRef = useRef(false)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const resizeCanvas = () => {
      canvas.width = canvas.offsetWidth * window.devicePixelRatio
      canvas.height = canvas.offsetHeight * window.devicePixelRatio
      ctx.scale(window.devicePixelRatio, window.devicePixelRatio)
    }

    const createParticle = (): Particle => {
      const maxLife = Math.random() * 300 + 200
      return {
        x: Math.random() * canvas.offsetWidth,
        y: Math.random() * canvas.offsetHeight,
        vx: (Math.random() - 0.5) * 0.5,
        vy: (Math.random() - 0.5) * 0.5,
        size: Math.random() * 2 + 0.5,
        opacity: Math.random() * 0.8 + 0.2,
        color: colors[Math.floor(Math.random() * colors.length)],
        life: maxLife,
        maxLife
      }
    }

    const initParticles = () => {
      particlesRef.current = []
      for (let i = 0; i < particleCount; i++) {
        particlesRef.current.push(createParticle())
      }
    }

    const updateParticle = (particle: Particle) => {
      // 基础移动
      particle.x += particle.vx
      particle.y += particle.vy

      // 边界反弹
      if (particle.x <= 0 || particle.x >= canvas.offsetWidth) {
        particle.vx *= -1
      }
      if (particle.y <= 0 || particle.y >= canvas.offsetHeight) {
        particle.vy *= -1
      }

      // 鼠标交互
      if (interactive && isMouseInCanvasRef.current) {
        const dx = mouseRef.current.x - particle.x
        const dy = mouseRef.current.y - particle.y
        const distance = Math.sqrt(dx * dx + dy * dy)
        const maxDistance = 120

        if (distance < maxDistance) {
          const force = (maxDistance - distance) / maxDistance
          const angle = Math.atan2(dy, dx)
          particle.vx -= Math.cos(angle) * force * 0.02
          particle.vy -= Math.sin(angle) * force * 0.02
        }
      }

      // 生命周期
      particle.life -= 1
      if (particle.life <= 0) {
        Object.assign(particle, createParticle())
      }

      // 透明度变化
      const lifeRatio = particle.life / particle.maxLife
      particle.opacity = Math.sin(lifeRatio * Math.PI) * 0.8 + 0.2
    }

    const drawParticle = (particle: Particle) => {
      ctx.save()
      ctx.globalAlpha = particle.opacity
      
      // 创建径向渐变
      const gradient = ctx.createRadialGradient(
        particle.x, particle.y, 0,
        particle.x, particle.y, particle.size * 3
      )
      gradient.addColorStop(0, particle.color)
      gradient.addColorStop(1, 'transparent')
      
      ctx.fillStyle = gradient
      ctx.beginPath()
      ctx.arc(particle.x, particle.y, particle.size * 3, 0, Math.PI * 2)
      ctx.fill()
      
      // 内核
      ctx.fillStyle = particle.color
      ctx.beginPath()
      ctx.arc(particle.x, particle.y, particle.size, 0, Math.PI * 2)
      ctx.fill()
      
      ctx.restore()
    }

    const drawConnections = () => {
      const particles = particlesRef.current
      const maxDistance = 100
      
      for (let i = 0; i < particles.length; i++) {
        for (let j = i + 1; j < particles.length; j++) {
          const dx = particles[i].x - particles[j].x
          const dy = particles[i].y - particles[j].y
          const distance = Math.sqrt(dx * dx + dy * dy)
          
          if (distance < maxDistance) {
            const opacity = (1 - distance / maxDistance) * 0.3
            ctx.save()
            ctx.globalAlpha = opacity
            ctx.strokeStyle = '#3b82f6'
            ctx.lineWidth = 0.5
            ctx.beginPath()
            ctx.moveTo(particles[i].x, particles[i].y)
            ctx.lineTo(particles[j].x, particles[j].y)
            ctx.stroke()
            ctx.restore()
          }
        }
      }
    }

    const animate = () => {
      ctx.clearRect(0, 0, canvas.offsetWidth, canvas.offsetHeight)
      
      // 更新和绘制粒子
      particlesRef.current.forEach(particle => {
        updateParticle(particle)
        drawParticle(particle)
      })
      
      // 绘制连接线
      drawConnections()
      
      animationRef.current = requestAnimationFrame(animate)
    }

    const handleMouseMove = (e: MouseEvent) => {
      const rect = canvas.getBoundingClientRect()
      mouseRef.current = {
        x: e.clientX - rect.left,
        y: e.clientY - rect.top
      }
    }

    const handleMouseEnter = () => {
      isMouseInCanvasRef.current = true
    }

    const handleMouseLeave = () => {
      isMouseInCanvasRef.current = false
    }

    const handleResize = () => {
      resizeCanvas()
      initParticles()
    }

    // 初始化
    resizeCanvas()
    initParticles()
    animate()

    // 事件监听
    if (interactive) {
      canvas.addEventListener('mousemove', handleMouseMove)
      canvas.addEventListener('mouseenter', handleMouseEnter)
      canvas.addEventListener('mouseleave', handleMouseLeave)
    }
    window.addEventListener('resize', handleResize)

    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current)
      }
      if (interactive) {
        canvas.removeEventListener('mousemove', handleMouseMove)
        canvas.removeEventListener('mouseenter', handleMouseEnter)
        canvas.removeEventListener('mouseleave', handleMouseLeave)
      }
      window.removeEventListener('resize', handleResize)
    }
  }, [particleCount, interactive, colors])

  return (
    <canvas
      ref={canvasRef}
      className={`absolute inset-0 pointer-events-${interactive ? 'auto' : 'none'} ${className}`}
      style={{
        width: '100%',
        height: '100%'
      }}
    />
  )
}

export default ParticleBackground