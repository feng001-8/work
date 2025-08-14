// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./VAMM.sol";
import "./Vault.sol";
import "./MarketRouter.sol";
import "./PositionsTracker.sol";
import "./MockUSDC.sol";

/**
 * @title DeployVAMM - vAMM 系统部署合约
 * @dev 一键部署完整的 vAMM 杠杆交易系统
 */
contract DeployVAMM {
    // 部署的合约地址
    address public mockUSDC;
    address public vamm;
    address public vault;
    address public marketRouter;
    address public positionsTracker;
    
    // 部署者地址
    address public deployer;
    
    // 事件
    event SystemDeployed(
        address indexed deployer,
        address mockUSDC,
        address vamm,
        address vault,
        address marketRouter,
        address positionsTracker
    );
    
    constructor() {
        deployer = msg.sender;
    }
    
    /**
     * @dev 部署完整的 vAMM 系统
     * @param initialUSDCSupply 初始 USDC 供应量
     * @return 所有合约地址
     */
    function deploySystem(uint256 initialUSDCSupply) external returns (
        address _mockUSDC,
        address _vamm,
        address _vault,
        address _marketRouter,
        address _positionsTracker
    ) {
        require(msg.sender == deployer, "DeployVAMM: only deployer");
        
        // 1. 部署 MockUSDC
        MockUSDC usdcContract = new MockUSDC(
            "Mock USDC",
            "USDC",
            6,
            initialUSDCSupply
        );
        mockUSDC = address(usdcContract);
        
        // 2. 部署 VAMM
        VAMM vammContract = new VAMM();
        vamm = address(vammContract);
        
        // 3. 部署 Vault
        Vault vaultContract = new Vault();
        vault = address(vaultContract);
        
        // 4. 部署 MarketRouter
        MarketRouter routerContract = new MarketRouter();
        marketRouter = address(routerContract);
        
        // 5. 部署 PositionsTracker
        PositionsTracker trackerContract = new PositionsTracker();
        positionsTracker = address(trackerContract);
        
        // 6. 初始化合约
        _initializeContracts();
        
        // 7. 转移所有权给部署者
        _transferOwnerships();
        
        emit SystemDeployed(
            deployer,
            mockUSDC,
            vamm,
            vault,
            marketRouter,
            positionsTracker
        );
        
        return (mockUSDC, vamm, vault, marketRouter, positionsTracker);
    }
    
    /**
     * @dev 初始化所有合约
     */
    function _initializeContracts() internal {
        // 初始化 VAMM
        VAMM(vamm).initialize(vault, positionsTracker);
        
        // 初始化 Vault
        Vault(vault).initialize(mockUSDC, vamm);
        
        // 初始化 MarketRouter
        MarketRouter(marketRouter).initialize(vault, vamm, mockUSDC);
        
        // 初始化 PositionsTracker
        PositionsTracker(positionsTracker).initialize(vamm, vault);
    }
    
    /**
     * @dev 转移所有合约的所有权给部署者
     */
    function _transferOwnerships() internal {
        VAMM(vamm).transferOwnership(deployer);
        Vault(vault).transferOwnership(deployer);
        MarketRouter(marketRouter).transferOwnership(deployer);
        PositionsTracker(positionsTracker).transferOwnership(deployer);
        MockUSDC(mockUSDC).transferOwnership(deployer);
    }
    
    /**
     * @dev 配置示例交易对（ETH/USDC）
     * @param ethAddress ETH 代币地址（或使用 WETH）
     * @param initialPrice ETH 初始价格（以 USDC 计价）
     */
    function setupETHPair(
        address ethAddress,
        uint256 initialPrice
    ) external {
        require(msg.sender == deployer, "DeployVAMM: only deployer");
        require(vamm != address(0), "DeployVAMM: system not deployed");
        
        // 计算虚拟流动性池参数
        // 假设初始虚拟 ETH 数量为 1000 ETH
        uint256 virtualETH = 1000 * 1e18;
        // 根据价格计算对应的 USDC 数量
        uint256 virtualUSDC = virtualETH * initialPrice / 1e18;
        
        // 在 VAMM 中设置 ETH 交易对
        VAMM(vamm).setTokenConfig(
            ethAddress,
            virtualETH,
            virtualUSDC,
            initialPrice
        );
        
        // 在 Vault 中启用 ETH
        Vault(vault).setTokenConfig(ethAddress, true);
        
        // 在 MarketRouter 中启用 ETH
        MarketRouter(marketRouter).setTokenConfig(ethAddress, true);
        
        // 在 PositionsTracker 中配置 ETH
        PositionsTracker(positionsTracker).setTokenConfig(
            ethAddress,
            100,      // fundingRateFactor (0.01%)
            50,       // stableFundingRateFactor (0.005%)
            1000,     // maxFundingRate (0.1%)
            8 hours   // fundingInterval
        );
    }
    
    /**
     * @dev 设置清算者
     * @param liquidator 清算者地址
     */
    function setLiquidator(address liquidator) external {
        require(msg.sender == deployer, "DeployVAMM: only deployer");
        require(marketRouter != address(0), "DeployVAMM: system not deployed");
        
        MarketRouter(marketRouter).setLiquidator(liquidator, true);
    }
    
    /**
     * @dev 获取系统状态
     * @return 系统是否已部署
     */
    function isSystemDeployed() external view returns (bool) {
        return vamm != address(0) && 
               vault != address(0) && 
               marketRouter != address(0) && 
               positionsTracker != address(0) && 
               mockUSDC != address(0);
    }
    
    /**
     * @dev 获取所有合约地址
     * @return 所有合约地址的结构体
     */
    function getContractAddresses() external view returns (
        address _mockUSDC,
        address _vamm,
        address _vault,
        address _marketRouter,
        address _positionsTracker
    ) {
        return (mockUSDC, vamm, vault, marketRouter, positionsTracker);
    }
}