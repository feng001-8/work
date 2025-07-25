import { createPublicClient, http, hexToBytes, Address } from 'viem';
import { mainnet } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
// import { signTransaction, sendRawTransaction } from 'viem/actions'; // These are now methods on client

// 类型断言与环境变量读取
const privateKey = import.meta.env.VITE_PRIVATE_KEY as any;
const infuraApiKey = import.meta.env.VITE_INFURA_API_KEY as any;

// 校验环境变量格式
if (!privateKey || !privateKey.startsWith('0x')) {
  throw new Error('VITE_PRIVATE_KEY 必须以 0x 开头');
}
if (!infuraApiKey) {
  throw new Error('请配置 VITE_INFURA_API_KEY');
}

// 1. 创建公共客户端（连接以太坊主网）
const publicClient = createPublicClient({
  chain: mainnet,
  transport: http(`https://mainnet.infura.io/v3/${infuraApiKey}`),
});

// 2. 转换私钥为账户对象（确保类型正确）
const account = privateKeyToAccount(privateKey);

// 3. ERC20转账参数（显式声明地址类型）
const erc20Address = '0x887fbe8e6ff2551f8494e830bb3e229812839de7';
const transferSelector = hexToBytes('0xa9059cbb'); // transfer函数选择器
const toAddress = '0x37Ad5A01C4aB8f7e27922782f6364634B634C817';
const amount = 100n; // 最小单位（需根据代币decimals调整）

// 4. 构建交易数据（修正字节处理逻辑）
const data = new Uint8Array([
  ...transferSelector,
  ...hexToBytes(toAddress.slice(2).padStart(64, '0')), // 接收地址（32字节）
  ...hexToBytes(amount.toString(16).padStart(64, '0')), // 金额（32字节）
]);

// 5. 构建交易对象（显式声明类型）
const transaction: Parameters<typeof publicClient.signTransaction>[0]['transaction'] = {
  to: erc20Address,
  value: 0n,
  data,
  gasPrice: null,
  gas: null,
  nonce: null,
};

// 6. 签名并发送交易
async function sendERC20Transfer() {
  try {
    // 签名交易（修正参数格式）
    const signedTx = await publicClient.signTransaction({
      account,
      ...transaction, // 传入交易对象
      client: publicClient,
    });

    // 发送已签名交易（使用 sendRawTransaction，参数为序列化交易）
    const txHash = await publicClient.sendRawTransaction({
      serializedTransaction: signedTx, // 正确字段名
    });

    console.log('交易已发送，哈希:', txHash);
    console.log('区块链浏览器查询:', `https://etherscan.io/tx/${txHash}`);
  } catch (error) {
    console.error('交易失败:', error);
  }
}

sendERC20Transfer();

