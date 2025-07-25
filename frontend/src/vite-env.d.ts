// 声明环境变量类型（需与实际使用的变量对应）
interface ImportMetaEnv {
  // 新增私钥的类型定义（用于读取私钥）
  VITE_PRIVATE_KEY: string;
  // 保留原有的 Infura API 密钥
  VITE_INFURA_API_KEY: string;
  // 保留原有的 Etherscan API 密钥（只读）
  readonly VITE_ETHERSCAN_API_KEY: string;
}

// 关联 ImportMeta 与环境变量类型
interface ImportMeta {
  readonly env: ImportMetaEnv;
}