import { http, parseEther, getContract, createWalletClient, publicActions } from 'viem'
import { sepolia } from 'viem/chains'
import { privateKeyToAccount } from 'viem/accounts'
import { describe, it, expect, beforeAll } from 'vitest'

// 合约 ABI
const tokenBankABI = [
  {
    "inputs": [
      { "internalType": "address", "name": "owner", "type": "address" },
      { "internalType": "address", "name": "delegate", "type": "address" },
      { "internalType": "uint256", "name": "amount", "type": "uint256" },
      { "internalType": "uint256", "name": "deadline", "type": "uint256" },
      { "internalType": "uint8", "name": "v", "type": "uint8" },
      { "internalType": "bytes32", "name": "r", "type": "bytes32" },
      { "internalType": "bytes32", "name": "s", "type": "bytes32" }
    ],
    "name": "delegateDepositWithPermit",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "address", "name": "_user", "type": "address" }],
    "name": "getBankBalance",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getTotalDeposits",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  }
] as const

const tokenABI = [
  {
    "inputs": [{ "internalType": "address", "name": "account", "type": "address" }],
    "name": "balanceOf",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "owner", "type": "address" },
      { "internalType": "address", "name": "spender", "type": "address" },
      { "internalType": "uint256", "name": "value", "type": "uint256" },
      { "internalType": "uint256", "name": "deadline", "type": "uint256" },
      { "internalType": "uint8", "name": "v", "type": "uint8" },
      { "internalType": "bytes32", "name": "r", "type": "bytes32" },
      { "internalType": "bytes32", "name": "s", "type": "bytes32" }
    ],
    "name": "permit",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "DOMAIN_SEPARATOR",
    "outputs": [{ "internalType": "bytes32", "name": "", "type": "bytes32" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "address", "name": "owner", "type": "address" }],
    "name": "nonces",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  }
] as const

// 测试账户 - 请提供您的 Sepolia 测试网私钥
const ownerAccount = privateKeyToAccount('0x3d5659adb9128f1493aedcdef4acc56f504431281b6bd5a58ce8a2987cc8b142' as `0x${string}`)
const delegateAccount = privateKeyToAccount('0x975f98bb5e845db49c490363dff5064c9bf11a5c3ec0f0506452b015f6620801' as `0x${string}`)

// Sepolia 测试网合约地址 - 请提供您的实际合约地址
const TOKEN_ADDRESS = '0x9B10283D311A758434212d8Cad690B3e8f4709Cd' as `0x${string}` // MyToken 合约地址
const TOKENBANK_ADDRESS = '0x18b46A37be9C945Cf0c44f5f2bC6f024eB04e071' as `0x${string}` // TokenBank 合约地址

// Sepolia RPC URL - 请使用您的 Infura/Alchemy 等 RPC 端点
const SEPOLIA_RPC_URL = 'https://sepolia.drpc.org'

describe('委托存款测试', () => {
  let testClient: any
  let ownerClient: any
  let delegateClient: any
  let tokenContract: any
  let tokenBankContract: any

  beforeAll(async () => {
    // 创建钱包客户端连接到 Sepolia 测试网
    ownerClient = createWalletClient({
      account: ownerAccount,
      chain: sepolia,
      transport: http(SEPOLIA_RPC_URL),
    }).extend(publicActions)

    delegateClient = createWalletClient({
      account: delegateAccount,
      chain: sepolia,
      transport: http(SEPOLIA_RPC_URL),
    }).extend(publicActions)

    // 创建合约实例
    tokenContract = getContract({
      address: TOKEN_ADDRESS,
      abi: tokenABI,
      client: ownerClient,
    })

    tokenBankContract = getContract({
      address: TOKENBANK_ADDRESS,
      abi: tokenBankABI,
      client: delegateClient,
    })
  })

  it('应该成功执行委托存款并正确更新余额', async () => {
    const amount = parseEther('1') // 减少测试金额到 1 个代币
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600) // 1小时后过期

    // 1. 检查合约是否存在并获取初始余额
    let initialOwnerTokenBalance: bigint
    let initialOwnerBankBalance: bigint
    let initialTotalDeposits: bigint
    
    try {
      console.log('\n正在检查合约状态...')
      
      // 检查代币合约
      const tokenCode = await ownerClient.getBytecode({ address: TOKEN_ADDRESS })
      if (!tokenCode || tokenCode === '0x') {
        throw new Error(`代币合约 ${TOKEN_ADDRESS} 不存在或未部署`)
      }
      console.log('✅ 代币合约存在')
      
      // 检查银行合约
      const bankCode = await delegateClient.getBytecode({ address: TOKENBANK_ADDRESS })
      if (!bankCode || bankCode === '0x') {
        throw new Error(`银行合约 ${TOKENBANK_ADDRESS} 不存在或未部署`)
      }
      console.log('✅ 银行合约存在')
      
      initialOwnerTokenBalance = await tokenContract.read.balanceOf([ownerAccount.address])
      initialOwnerBankBalance = await tokenBankContract.read.getBankBalance([ownerAccount.address])
      initialTotalDeposits = await tokenBankContract.read.getTotalDeposits()
      
    } catch (error) {
      console.error('合约检查失败:', error)
      throw error
    }

    console.log('初始状态:')
    console.log('- 授权者代币余额:', initialOwnerTokenBalance.toString())
    console.log('- 授权者银行余额:', initialOwnerBankBalance.toString())
    console.log('- 银行总存款:', initialTotalDeposits.toString())

    // 2. 获取 nonce 和 domain separator
    const nonce = await tokenContract.read.nonces([ownerAccount.address])
    const domainSeparator = await tokenContract.read.DOMAIN_SEPARATOR()

    // 3. 构建 EIP-2612 签名数据
    const domain = {
      name: 'MyToken',
      version: '1',
      chainId: sepolia.id,
      verifyingContract: TOKEN_ADDRESS,
    }

    const types = {
      Permit: [
        { name: 'owner', type: 'address' },
        { name: 'spender', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
      ],
    }

    const message = {
      owner: ownerAccount.address,
      spender: TOKENBANK_ADDRESS,
      value: amount,
      nonce: nonce,
      deadline: deadline,
    }

    // 4. 生成签名
    const signature = await ownerClient.signTypedData({
      domain,
      types,
      primaryType: 'Permit',
      message,
    })

    // 解析签名
    const r = signature.slice(0, 66) as `0x${string}`
    const s = `0x${signature.slice(66, 130)}` as `0x${string}`
    const v = parseInt(signature.slice(130, 132), 16)

    console.log('签名信息:')
    console.log('- r:', r)
    console.log('- s:', s)
    console.log('- v:', v)

    // 5. 执行委托存款
    const txHash = await tokenBankContract.write.delegateDepositWithPermit([
      ownerAccount.address,
      delegateAccount.address,
      amount,
      deadline,
      v,
      r,
      s,
    ])

    console.log('交易哈希:', txHash)

    // 等待交易确认并获取最终余额
    console.log('等待交易确认...')
    const receipt = await delegateClient.waitForTransactionReceipt({ 
      hash: txHash,
      timeout: 60000 // 60秒超时
    })
    console.log('交易确认:', receipt.status)

    // 等待一小段时间确保状态更新
    await new Promise(resolve => setTimeout(resolve, 2000))
    
    // 6. 检查最终余额
    const finalOwnerTokenBalance = await tokenContract.read.balanceOf([ownerAccount.address])
    const finalOwnerBankBalance = await tokenBankContract.read.getBankBalance([ownerAccount.address])
    const finalTotalDeposits = await tokenBankContract.read.getTotalDeposits()

    console.log('最终状态:')
    console.log('- 授权者代币余额:', finalOwnerTokenBalance.toString())
    console.log('- 授权者银行余额:', finalOwnerBankBalance.toString())
    console.log('- 银行总存款:', finalTotalDeposits.toString())

    // 7. 验证余额变化
    expect(finalOwnerTokenBalance).toBe(initialOwnerTokenBalance - amount)
    expect(finalOwnerBankBalance).toBe(initialOwnerBankBalance + amount)
    expect(finalTotalDeposits).toBe(initialTotalDeposits + amount)

    console.log('✅ 委托存款测试通过！')
  }, 120000) // 设置测试超时时间为120秒
})