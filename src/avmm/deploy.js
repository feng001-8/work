const { ethers } = require('hardhat');

/**
 * vAMM 杠杆交易系统部署脚本
 * 部署顺序：MockUSDC -> VAMM -> Vault -> PositionsTracker -> MarketRouter -> DeployVAMM
 */
async function main() {
    console.log('开始部署 vAMM 杠杆交易系统...');
    
    const [deployer] = await ethers.getSigners();
    console.log('部署账户:', deployer.address);
    console.log('账户余额:', ethers.utils.formatEther(await deployer.getBalance()));
    
    // 1. 部署 MockUSDC
    console.log('\n1. 部署 MockUSDC...');
    const MockUSDC = await ethers.getContractFactory('MockUSDC');
    const usdc = await MockUSDC.deploy();
    await usdc.deployed();
    console.log('MockUSDC 部署地址:', usdc.address);
    
    // 2. 部署 VAMM
    console.log('\n2. 部署 VAMM...');
    const VAMM = await ethers.getContractFactory('VAMM');
    const vamm = await VAMM.deploy();
    await vamm.deployed();
    console.log('VAMM 部署地址:', vamm.address);
    
    // 3. 部署 Vault
    console.log('\n3. 部署 Vault...');
    const Vault = await ethers.getContractFactory('Vault');
    const vault = await Vault.deploy();
    await vault.deployed();
    console.log('Vault 部署地址:', vault.address);
    
    // 4. 部署 PositionsTracker
    console.log('\n4. 部署 PositionsTracker...');
    const PositionsTracker = await ethers.getContractFactory('PositionsTracker');
    const positionsTracker = await PositionsTracker.deploy();
    await positionsTracker.deployed();
    console.log('PositionsTracker 部署地址:', positionsTracker.address);
    
    // 5. 部署 MarketRouter
    console.log('\n5. 部署 MarketRouter...');
    const MarketRouter = await ethers.getContractFactory('MarketRouter');
    const marketRouter = await MarketRouter.deploy();
    await marketRouter.deployed();
    console.log('MarketRouter 部署地址:', marketRouter.address);
    
    // 6. 部署 VAMMExample
    console.log('\n6. 部署 VAMMExample...');
    const VAMMExample = await ethers.getContractFactory('VAMMExample');
    const vammExample = await VAMMExample.deploy(
        marketRouter.address,
        vamm.address,
        vault.address,
        usdc.address
    );
    await vammExample.deployed();
    console.log('VAMMExample 部署地址:', vammExample.address);
    
    // 7. 初始化合约
    console.log('\n7. 初始化合约...');
    
    // 初始化 VAMM
    await vamm.initialize(vault.address, positionsTracker.address);
    console.log('VAMM 初始化完成');
    
    // 初始化 Vault
    await vault.initialize(vamm.address, usdc.address);
    console.log('Vault 初始化完成');
    
    // 初始化 PositionsTracker
    await positionsTracker.initialize();
    console.log('PositionsTracker 初始化完成');
    
    // 初始化 MarketRouter
    await marketRouter.initialize(vault.address, vamm.address, usdc.address);
    console.log('MarketRouter 初始化完成');
    
    // 8. 配置系统参数
    console.log('\n8. 配置系统参数...');
    
    // 设置 VAMM 允许的价格偏差（5%）
    await vamm.setAllowedPriceDeviation(500); // 5%
    console.log('设置 VAMM 价格偏差限制: 5%');
    
    // 9. 添加测试代币配置
    console.log('\n9. 添加测试代币配置...');
    
    // 模拟 ETH 地址（实际应该是 WETH 或其他代币）
    const ETH_ADDRESS = '0x0000000000000000000000000000000000000001';
    const BTC_ADDRESS = '0x0000000000000000000000000000000000000002';
    
    // 配置 ETH
    await vamm.setTokenConfig(
        ETH_ADDRESS,
        ethers.utils.parseEther('1000000'), // 1M 流动性
        ethers.utils.parseEther('2000')     // $2000 初始价格
    );
    
    await vault.setTokenConfig(
        ETH_ADDRESS,
        true,  // 启用
        50,    // 最大杠杆 50x
        9000,  // 清算阈值 90%
        100    // 清算费用 1%
    );
    
    await positionsTracker.setTokenConfig(
        ETH_ADDRESS,
        100,   // 资金费率基数 0.01%
        3600,  // 更新间隔 1小时
        500    // 流动性偏差 5%
    );
    
    await marketRouter.setTokenConfig(ETH_ADDRESS, true);
    
    console.log('ETH 配置完成');
    
    // 配置 BTC
    await vamm.setTokenConfig(
        BTC_ADDRESS,
        ethers.utils.parseEther('500000'),  // 500K 流动性
        ethers.utils.parseEther('40000')    // $40000 初始价格
    );
    
    await vault.setTokenConfig(
        BTC_ADDRESS,
        true,  // 启用
        50,    // 最大杠杆 50x
        9000,  // 清算阈值 90%
        100    // 清算费用 1%
    );
    
    await positionsTracker.setTokenConfig(
        BTC_ADDRESS,
        100,   // 资金费率基数 0.01%
        3600,  // 更新间隔 1小时
        500    // 流动性偏差 5%
    );
    
    await marketRouter.setTokenConfig(BTC_ADDRESS, true);
    
    console.log('BTC 配置完成');
    
    // 10. 设置清算者
    console.log('\n10. 设置清算者...');
    await marketRouter.setLiquidator(deployer.address, true);
    console.log('设置部署者为清算者');
    
    // 11. 铸造测试 USDC
    console.log('\n11. 铸造测试 USDC...');
    await usdc.mint(deployer.address, ethers.utils.parseUnits('1000000', 6)); // 1M USDC
    console.log('铸造 1,000,000 USDC 给部署者');
    
    // 12. 输出部署信息
    console.log('\n=== 部署完成 ===');
    console.log('合约地址:');
    console.log('MockUSDC:', usdc.address);
    console.log('VAMM:', vamm.address);
    console.log('Vault:', vault.address);
    console.log('PositionsTracker:', positionsTracker.address);
    console.log('MarketRouter:', marketRouter.address);
    console.log('VAMMExample:', vammExample.address);
    
    console.log('\n支持的交易对:');
    console.log('ETH/USD - 初始价格: $2,000');
    console.log('BTC/USD - 初始价格: $40,000');
    
    console.log('\n系统配置:');
    console.log('最大杠杆: 50x');
    console.log('清算阈值: 90%');
    console.log('价格偏差限制: 5%');
    
    // 13. 验证部署
    console.log('\n=== 验证部署 ===');
    
    // 检查 ETH 价格
    const ethPrice = await vamm.getPrice(ETH_ADDRESS);
    console.log('ETH 当前价格:', ethers.utils.formatEther(ethPrice));
    
    // 检查 BTC 价格
    const btcPrice = await vamm.getPrice(BTC_ADDRESS);
    console.log('BTC 当前价格:', ethers.utils.formatEther(btcPrice));
    
    // 检查 USDC 余额
    const usdcBalance = await usdc.balanceOf(deployer.address);
    console.log('部署者 USDC 余额:', ethers.utils.formatUnits(usdcBalance, 6));
    
    console.log('\n部署验证完成！');
    
    return {
        usdc: usdc.address,
        vamm: vamm.address,
        vault: vault.address,
        positionsTracker: positionsTracker.address,
        marketRouter: marketRouter.address,
        vammExample: vammExample.address,
        deployer: deployer.address
    };
}

// 错误处理
main()
    .then((addresses) => {
        console.log('\n部署成功！合约地址已保存。');
        process.exit(0);
    })
    .catch((error) => {
        console.error('部署失败:', error);
        process.exit(1);
    });

module.exports = main;