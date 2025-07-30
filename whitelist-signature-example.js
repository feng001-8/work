// 白名单签名生成示例
// 这个脚本演示了项目方如何为白名单用户生成签名

const { ethers } = require('ethers');

// EIP-712 域分隔符
const domain = {
    name: 'NFTMarket',
    version: '1',
    chainId: 1, // 主网，根据实际网络修改
    verifyingContract: '0x...' // NFTMarket合约地址
};

// 白名单许可类型定义
const types = {
    WhitelistPermit: [
        { name: 'buyer', type: 'address' },
        { name: 'listingId', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
        { name: 'nonce', type: 'uint256' }
    ]
};

// 生成白名单签名的函数
async function generateWhitelistSignature(projectOwnerPrivateKey, whitelistData) {
    // 创建项目方钱包
    const projectOwnerWallet = new ethers.Wallet(projectOwnerPrivateKey);
    
    // 签名数据
    const signature = await projectOwnerWallet._signTypedData(domain, types, whitelistData);
    
    return signature;
}

// 使用示例
async function example() {
    // 项目方私钥（实际使用时请妥善保管）
    const projectOwnerPrivateKey = '0x...';
    
    // 白名单数据
    const whitelistData = {
        buyer: '0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6', // 白名单用户地址
        listingId: 1, // NFT listing ID
        deadline: Math.floor(Date.now() / 1000) + 3600, // 1小时后过期
        nonce: 0 // 用户当前nonce（从合约获取）
    };
    
    try {
        const signature = await generateWhitelistSignature(projectOwnerPrivateKey, whitelistData);
        
        console.log('白名单签名生成成功:');
        console.log('买家地址:', whitelistData.buyer);
        console.log('NFT ID:', whitelistData.listingId);
        console.log('过期时间:', new Date(whitelistData.deadline * 1000));
        console.log('Nonce:', whitelistData.nonce);
        console.log('签名:', signature);
        
        // 用户可以使用这些参数调用 permitBuy 函数
        console.log('\n调用 permitBuy 的参数:');
        console.log(`permitBuy(${whitelistData.listingId}, ${whitelistData.deadline}, ${whitelistData.nonce}, "${signature}")`);
        
    } catch (error) {
        console.error('签名生成失败:', error);
    }
}

// 验证签名的函数（可选，用于测试）
async function verifySignature(signature, whitelistData, expectedSigner) {
    try {
        const recoveredAddress = ethers.utils.verifyTypedData(domain, types, whitelistData, signature);
        console.log('签名验证结果:');
        console.log('恢复的地址:', recoveredAddress);
        console.log('期望的地址:', expectedSigner);
        console.log('验证通过:', recoveredAddress.toLowerCase() === expectedSigner.toLowerCase());
        
        return recoveredAddress.toLowerCase() === expectedSigner.toLowerCase();
    } catch (error) {
        console.error('签名验证失败:', error);
        return false;
    }
}

// 运行示例
if (require.main === module) {
    example();
}

module.exports = {
    generateWhitelistSignature,
    verifySignature,
    domain,
    types
};