import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    testTimeout: 120000, // 120秒超时 - 区块链交易可能需要更长时间
    hookTimeout: 60000, // 钩子函数60秒超时
    teardownTimeout: 60000, // 清理60秒超时
    globals: true,
    environment: 'node'
  }
})