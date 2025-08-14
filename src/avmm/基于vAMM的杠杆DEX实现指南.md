# 基于 vAMM 的杠杆 DEX 实现指南

## 概述

本指南将教你如何实现一个基于虚拟自动做市商（vAMM）的杠杆去中心化交易所。vAMM 是一种创新的 DeFi 机制，它使用虚拟流动性池来确定价格，而不需要真实的流动性提供者。

## 核心概念

### 什么是 vAMM？

vAMM（Virtual Automated Market Maker）是传统 AMM 的改进版本：
- **虚拟流动性**：使用数学公式模拟流动性池，无需真实代币储备
- **价格发现**：通过 x * y = k 公式计算标记价格
- **杠杆交易**：支持多倍杠杆的永续合约交易
- **资金费率**：通过资金费率机制平衡多空仓位

### 系统架构

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   MarketRouter  │────│      VAMM       │────│ PositionsTracker│
│   (交易路由)     │    │   (虚拟AMM)      │    │   (仓位跟踪)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│      Vault      │────│   OrderBook     │────│   LPManager     │
│   (资金管理)     │    │   (订单簿)       │    │  (流动性管理)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 核心合约实现

### 1. VAMM 合约 - 虚拟自动做市商

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title VAMM - 虚拟自动做市商
 * @dev 实现基于恒定乘积公式的虚拟流动性池
 */
contract VAMM {
    using Math for uint256;
    
    // 最小流动性要求
    uint256 public constant MIN_LIQUIDITY = 2e27;
    // 最大允许价格偏差
    uint256 public constant MAX_ALLOWED_PRICE_DEVIATION = 100;
    
    // 交易对结构体
    struct Pair {
        uint256 indexAmount;    // 指数代币数量
        uint256 stableAmount;   // 稳定币数量
        uint256 liquidity;      // 流动性 (indexAmount * stableAmount)
        uint256 lastUpdateTime; // 最后更新时间
    }
    
    // 状态变量
    mapping(address => Pair) public pairs;
    mapping(address => bool) public whitelistedToken;
    
    /**
     * @dev 设置交易对配置
     * @param indexToken 指数代币地址
     * @param indexAmount 初始指数代币数量
     * @param stableAmount 初始稳定币数量
     * @param referencePrice 参考价格
     */
    function setTokenConfig(
        address indexToken,
        uint256 indexAmount,
        uint256 stableAmount,
        uint256 referencePrice
    ) external {
        // 验证流动性
        require(indexAmount * stableAmount >= MIN_LIQUIDITY, "VAMM: insufficient liquidity");
        
        // 验证价格偏差
        _validatePriceDeviation(indexToken, indexAmount, stableAmount, referencePrice, true);
        
        Pair storage pair = pairs[indexToken];
        pair.indexAmount = indexAmount;
        pair.stableAmount = stableAmount;
        pair.liquidity = indexAmount * stableAmount;
        pair.lastUpdateTime = block.timestamp;
        
        whitelistedToken[indexToken] = true;
    }
    
    /**
     * @dev 获取当前标记价格
     * @param indexToken 指数代币地址
     * @return 标记价格 (稳定币/指数代币)
     */
    function getPrice(address indexToken) public view returns (uint256) {
        Pair memory pair = pairs[indexToken];
        return pair.stableAmount.mulDiv(1e18, pair.indexAmount);
    }
    
    /**
     * @dev 预计算交易后的价格
     * @param indexToken 指数代币地址
     * @param sizeDelta 交易规模变化
     * @param increase 是否增加仓位
     * @param long 是否做多
     * @return newStableAmount 新的稳定币数量
     * @return newIndexAmount 新的指数代币数量
     * @return markPrice 标记价格
     */
    function preCalculatePrice(
        address indexToken,
        uint256 sizeDelta,
        bool increase,
        bool long
    ) public view returns (
        uint256 newStableAmount,
        uint256 newIndexAmount,
        uint256 markPrice
    ) {
        Pair memory pair = pairs[indexToken];
        uint256 outputIndexed;
        
        // 根据交易方向计算新的池子状态
        if ((increase && !long) || (!increase && long)) {
            // 卖出指数代币或平多仓
            newStableAmount = pair.stableAmount - sizeDelta;
            newIndexAmount = pair.liquidity / newStableAmount;
            outputIndexed = newIndexAmount - pair.indexAmount;
        } else {
            // 买入指数代币或平空仓
            newStableAmount = pair.stableAmount + sizeDelta;
            newIndexAmount = pair.liquidity / newStableAmount;
            outputIndexed = pair.indexAmount - newIndexAmount;
        }
        
        // 计算平均执行价格
        markPrice = sizeDelta.mulDiv(1e18, outputIndexed);
    }
    
    /**
     * @dev 更新虚拟池状态
     * @param user 用户地址
     * @param indexToken 指数代币地址
     * @param collateralDelta 保证金变化
     * @param sizeDelta 仓位规模变化
     * @param long 是否做多
     * @param increase 是否增加仓位
     */
    function updateIndex(
        address user,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool long,
        bool increase,
        bool liquidation,
        address feeReceiver
    ) external {
        require(whitelistedToken[indexToken], "VAMM: token not whitelisted");
        
        Pair storage pair = pairs[indexToken];
        uint256 markPrice = getPrice(indexToken);
        
        if (sizeDelta > 0) {
            uint256 newStableAmount;
            uint256 newIndexAmount;
            (newStableAmount, newIndexAmount, markPrice) = preCalculatePrice(
                indexToken,
                sizeDelta,
                increase,
                long
            );
            
            // 更新虚拟池状态
            pair.stableAmount = newStableAmount;
            pair.indexAmount = newIndexAmount;
        }
        
        // 调用 Vault 更新用户仓位
        if (increase) {
            IVault(vault).increasePosition(
                user,
                indexToken,
                collateralDelta,
                sizeDelta,
                long,
                markPrice
            );
        } else {
            if (!liquidation) {
                IVault(vault).decreasePosition(
                    user,
                    indexToken,
                    collateralDelta,
                    sizeDelta,
                    long,
                    markPrice
                );
            } else {
                IVault(vault).liquidatePosition(
                    user,
                    indexToken,
                    sizeDelta,
                    long,
                    feeReceiver
                );
            }
        }
    }
    
    /**
     * @dev 验证价格偏差是否在允许范围内
     */
    function _validatePriceDeviation(
        address indexToken,
        uint256 indexAmount,
        uint256 stableAmount,
        uint256 referencePrice,
        bool init
    ) internal view {
        uint256 currentPrice = init ? referencePrice : getPrice(indexToken);
        uint256 newPrice = stableAmount.mulDiv(1e18, indexAmount);
        uint256 maxPriceDelta = currentPrice.mulDiv(allowedPriceDeviation, 10000);
        
        if (newPrice > currentPrice) {
            require(
                currentPrice + maxPriceDelta >= newPrice,
                "VAMM: price deviation too high"
            );
        } else {
            require(
                newPrice >= currentPrice - maxPriceDelta,
                "VAMM: price deviation too low"
            );
        }
    }
}
```

### 2. Vault 合约 - 资金和仓位管理

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vault - 资金和仓位管理合约
 * @dev 管理用户保证金、仓位和借贷
 */
contract Vault {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    // 仓位结构体
    struct Position {
        uint256 size;           // 仓位规模
        uint256 collateral;     // 保证金
        uint256 entryPrice;     // 开仓价格
        uint256 lastUpdateTime; // 最后更新时间
        bool long;              // 是否做多
    }
    
    // 状态变量
    mapping(bytes32 => Position) public positions;
    mapping(address => bool) public whitelistedToken;
    
    address public stable;  // 稳定币地址
    address public VAMM;    // VAMM 合约地址
    
    /**
     * @dev 增加仓位
     * @param user 用户地址
     * @param indexToken 指数代币地址
     * @param collateralDelta 保证金增量
     * @param sizeDelta 仓位规模增量
     * @param long 是否做多
     * @param markPrice 标记价格
     */
    function increasePosition(
        address user,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool long,
        uint256 markPrice
    ) external {
        require(msg.sender == VAMM, "Vault: invalid caller");
        require(whitelistedToken[indexToken], "Vault: token not whitelisted");
        
        bytes32 key = _getPositionKey(user, indexToken, long);
        Position storage position = positions[key];
        
        // 收取保证金
        if (collateralDelta > 0) {
            IERC20(stable).safeTransferFrom(user, address(this), collateralDelta);
        }
        
        // 更新仓位
        if (position.size == 0) {
            // 新开仓位
            position.entryPrice = markPrice;
        } else {
            // 加仓，重新计算平均开仓价格
            uint256 totalSize = position.size + sizeDelta;
            position.entryPrice = (position.size * position.entryPrice + sizeDelta * markPrice) / totalSize;
        }
        
        position.size += sizeDelta;
        position.collateral += collateralDelta;
        position.lastUpdateTime = block.timestamp;
        position.long = long;
        
        // 验证杠杆率
        _validateLeverage(position.size, position.collateral);
    }
    
    /**
     * @dev 减少仓位
     * @param user 用户地址
     * @param indexToken 指数代币地址
     * @param collateralDelta 保证金减量
     * @param sizeDelta 仓位规模减量
     * @param long 是否做多
     * @param markPrice 标记价格
     */
    function decreasePosition(
        address user,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool long,
        uint256 markPrice
    ) external {
        require(msg.sender == VAMM, "Vault: invalid caller");
        require(whitelistedToken[indexToken], "Vault: token not whitelisted");
        
        bytes32 key = _getPositionKey(user, indexToken, long);
        Position storage position = positions[key];
        
        require(position.size >= sizeDelta, "Vault: insufficient position size");
        
        // 计算盈亏
        (uint256 pnl, bool hasProfit) = _calculatePnL(
            position.size,
            position.entryPrice,
            markPrice,
            long
        );
        
        // 按比例计算本次平仓的盈亏
        uint256 proportionalPnL = pnl * sizeDelta / position.size;
        
        // 更新仓位
        position.size -= sizeDelta;
        
        uint256 collateralToReturn = collateralDelta;
        
        if (hasProfit) {
            // 盈利情况
            collateralToReturn += proportionalPnL;
        } else {
            // 亏损情况
            if (proportionalPnL >= position.collateral) {
                // 保证金不足以覆盖亏损
                collateralToReturn = 0;
                position.collateral = 0;
            } else {
                position.collateral -= proportionalPnL;
                if (collateralToReturn > position.collateral) {
                    collateralToReturn = position.collateral;
                }
                position.collateral -= collateralToReturn;
            }
        }
        
        // 返还保证金
        if (collateralToReturn > 0) {
            IERC20(stable).safeTransfer(user, collateralToReturn);
        }
        
        // 如果仓位完全平仓，删除记录
        if (position.size == 0) {
            delete positions[key];
        } else {
            // 验证剩余仓位的杠杆率
            _validateLeverage(position.size, position.collateral);
        }
    }
    
    /**
     * @dev 清算仓位
     * @param user 用户地址
     * @param indexToken 指数代币地址
     * @param sizeDelta 清算规模
     * @param long 是否做多
     * @param feeReceiver 清算费用接收者
     */
    function liquidatePosition(
        address user,
        address indexToken,
        uint256 sizeDelta,
        bool long,
        address feeReceiver
    ) external {
        require(msg.sender == VAMM, "Vault: invalid caller");
        
        bytes32 key = _getPositionKey(user, indexToken, long);
        Position storage position = positions[key];
        
        require(position.size >= sizeDelta, "Vault: insufficient position size");
        
        // 验证是否可以清算
        require(_isLiquidatable(key, indexToken), "Vault: position not liquidatable");
        
        // 计算清算费用
        uint256 liquidationFee = sizeDelta * 50 / 10000; // 0.5% 清算费用
        
        // 更新仓位
        position.size -= sizeDelta;
        
        if (position.collateral > liquidationFee) {
            position.collateral -= liquidationFee;
            // 支付清算费用给清算者
            IERC20(stable).safeTransfer(feeReceiver, liquidationFee);
        } else {
            // 保证金不足以支付清算费用
            IERC20(stable).safeTransfer(feeReceiver, position.collateral);
            position.collateral = 0;
        }
        
        // 如果仓位完全清算，删除记录
        if (position.size == 0) {
            delete positions[key];
        }
    }
    
    /**
     * @dev 计算仓位盈亏
     * @param size 仓位规模
     * @param entryPrice 开仓价格
     * @param markPrice 标记价格
     * @param long 是否做多
     * @return pnl 盈亏金额
     * @return hasProfit 是否盈利
     */
    function _calculatePnL(
        uint256 size,
        uint256 entryPrice,
        uint256 markPrice,
        bool long
    ) internal pure returns (uint256 pnl, bool hasProfit) {
        if (long) {
            if (markPrice > entryPrice) {
                hasProfit = true;
                pnl = size * (markPrice - entryPrice) / entryPrice;
            } else {
                hasProfit = false;
                pnl = size * (entryPrice - markPrice) / entryPrice;
            }
        } else {
            if (entryPrice > markPrice) {
                hasProfit = true;
                pnl = size * (entryPrice - markPrice) / entryPrice;
            } else {
                hasProfit = false;
                pnl = size * (markPrice - entryPrice) / entryPrice;
            }
        }
    }
    
    /**
     * @dev 验证杠杆率
     * @param size 仓位规模
     * @param collateral 保证金
     */
    function _validateLeverage(uint256 size, uint256 collateral) internal pure {
        require(collateral > 0, "Vault: zero collateral");
        uint256 leverage = size * 1e18 / collateral;
        require(leverage <= 50 * 1e18, "Vault: leverage too high"); // 最大50倍杠杆
    }
    
    /**
     * @dev 检查仓位是否可以清算
     * @param key 仓位键
     * @param indexToken 指数代币地址
     * @return 是否可以清算
     */
    function _isLiquidatable(bytes32 key, address indexToken) internal view returns (bool) {
        Position memory position = positions[key];
        uint256 markPrice = IVAMM(VAMM).getPrice(indexToken);
        
        (uint256 pnl, bool hasProfit) = _calculatePnL(
            position.size,
            position.entryPrice,
            markPrice,
            position.long
        );
        
        if (hasProfit) {
            return false;
        }
        
        // 如果亏损超过保证金的90%，则可以清算
        return pnl >= position.collateral * 90 / 100;
    }
    
    /**
     * @dev 生成仓位键
     * @param user 用户地址
     * @param indexToken 指数代币地址
     * @param long 是否做多
     * @return 仓位键
     */
    function _getPositionKey(
        address user,
        address indexToken,
        bool long
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, indexToken, long));
    }
}
```

### 3. MarketRouter 合约 - 交易路由

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MarketRouter - 交易路由合约
 * @dev 处理用户交易请求和路由
 */
contract MarketRouter {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    // 最小仓位价值
    uint256 public constant MIN_POSITION_WORTH = 10e18;
    
    address public vault;
    address public VAMM;
    address public stable;
    
    mapping(address => bool) public whitelistedToken;
    mapping(address => bool) public liquidators;
    
    /**
     * @dev 增加仓位
     * @param indexToken 指数代币地址
     * @param collateralDelta 保证金增量
     * @param sizeDelta 仓位规模增量
     * @param long 是否做多
     */
    function increasePosition(
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool long
    ) external {
        require(whitelistedToken[indexToken], "MarketRouter: token not whitelisted");
        require(collateralDelta > 0, "MarketRouter: zero collateral");
        require(sizeDelta > 0, "MarketRouter: zero size");
        
        // 验证最小仓位价值
        require(sizeDelta >= MIN_POSITION_WORTH, "MarketRouter: position too small");
        
        // 调用 VAMM 更新虚拟池并开仓
        IVAMM(VAMM).updateIndex(
            msg.sender,
            indexToken,
            collateralDelta,
            sizeDelta,
            long,
            true,  // increase
            false, // not liquidation
            address(0)
        );
    }
    
    /**
     * @dev 减少仓位
     * @param indexToken 指数代币地址
     * @param collateralDelta 保证金减量
     * @param sizeDelta 仓位规模减量
     * @param long 是否做多
     */
    function decreasePosition(
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool long
    ) external {
        require(whitelistedToken[indexToken], "MarketRouter: token not whitelisted");
        require(sizeDelta > 0, "MarketRouter: zero size");
        
        // 调用 VAMM 更新虚拟池并平仓
        IVAMM(VAMM).updateIndex(
            msg.sender,
            indexToken,
            collateralDelta,
            sizeDelta,
            long,
            false, // decrease
            false, // not liquidation
            address(0)
        );
    }
    
    /**
     * @dev 清算仓位
     * @param user 被清算用户地址
     * @param indexToken 指数代币地址
     * @param sizeDelta 清算规模
     * @param long 是否做多
     */
    function liquidatePosition(
        address user,
        address indexToken,
        uint256 sizeDelta,
        bool long
    ) external {
        require(liquidators[msg.sender], "MarketRouter: not liquidator");
        require(whitelistedToken[indexToken], "MarketRouter: token not whitelisted");
        
        // 调用 VAMM 执行清算
        IVAMM(VAMM).updateIndex(
            user,
            indexToken,
            0,     // no collateral change
            sizeDelta,
            long,
            false, // decrease
            true,  // liquidation
            msg.sender // fee receiver
        );
    }
}
```

### 4. PositionsTracker 合约 - 仓位跟踪和资金费率

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title PositionsTracker - 仓位跟踪合约
 * @dev 跟踪全局仓位信息并计算资金费率
 */
contract PositionsTracker {
    using Math for uint256;
    
    // 配置结构体
    struct Config {
        uint256 totalLongSizes;     // 总做多仓位
        uint256 totalShortSizes;    // 总做空仓位
        uint256 totalLongAssets;    // 总做多资产
        uint256 totalShortAssets;   // 总做空资产
        uint256 maxTotalLongSizes;  // 最大做多仓位限制
        uint256 maxTotalShortSizes; // 最大做空仓位限制
    }
    
    mapping(address => Config) public configs;
    mapping(address => bool) public whitelistedToken;
    
    address public vault;
    address public VAMM;
    
    /**
     * @dev 增加总仓位规模
     * @param indexToken 指数代币地址
     * @param sizeDelta 仓位规模增量
     * @param markPrice 标记价格
     * @param long 是否做多
     */
    function increaseTotalSizes(
        address indexToken,
        uint256 sizeDelta,
        uint256 markPrice,
        bool long
    ) external {
        require(msg.sender == VAMM, "PositionsTracker: invalid caller");
        require(whitelistedToken[indexToken], "PositionsTracker: token not whitelisted");
        
        Config storage config = configs[indexToken];
        
        if (long) {
            config.totalLongSizes += sizeDelta;
            config.totalLongAssets += sizeDelta.mulDiv(1e18, markPrice);
            
            // 检查是否超过最大限制
            require(
                config.totalLongSizes <= config.maxTotalLongSizes,
                "PositionsTracker: max long size exceeded"
            );
        } else {
            config.totalShortSizes += sizeDelta;
            config.totalShortAssets += sizeDelta.mulDiv(1e18, markPrice);
            
            // 检查是否超过最大限制
            require(
                config.totalShortSizes <= config.maxTotalShortSizes,
                "PositionsTracker: max short size exceeded"
            );
        }
    }
    
    /**
     * @dev 减少总仓位规模
     * @param indexToken 指数代币地址
     * @param sizeDelta 仓位规模减量
     * @param markPrice 标记价格
     * @param long 是否做多
     */
    function decreaseTotalSizes(
        address indexToken,
        uint256 sizeDelta,
        uint256 markPrice,
        bool long
    ) external {
        require(msg.sender == VAMM, "PositionsTracker: invalid caller");
        require(whitelistedToken[indexToken], "PositionsTracker: token not whitelisted");
        
        Config storage config = configs[indexToken];
        
        if (long) {
            config.totalLongSizes -= sizeDelta;
            uint256 assetDelta = sizeDelta.mulDiv(1e18, markPrice);
            config.totalLongAssets = config.totalLongAssets > assetDelta 
                ? config.totalLongAssets - assetDelta 
                : 0;
        } else {
            config.totalShortSizes -= sizeDelta;
            uint256 assetDelta = sizeDelta.mulDiv(1e18, markPrice);
            config.totalShortAssets = config.totalShortAssets > assetDelta 
                ? config.totalShortAssets - assetDelta 
                : 0;
        }
    }
    
    /**
     * @dev 计算资金费率
     * @param indexToken 指数代币地址
     * @return fundingRate 资金费率 (正数表示多方支付空方)
     */
    function calculateFundingRate(address indexToken) external view returns (int256 fundingRate) {
        Config memory config = configs[indexToken];
        
        if (config.totalLongSizes == 0 && config.totalShortSizes == 0) {
            return 0;
        }
        
        // 计算多空比例
        uint256 totalSizes = config.totalLongSizes + config.totalShortSizes;
        uint256 longRatio = config.totalLongSizes.mulDiv(1e18, totalSizes);
        
        // 资金费率 = (多方比例 - 0.5) * 基础费率
        // 如果多方比例 > 50%，多方支付空方；反之空方支付多方
        int256 imbalance = int256(longRatio) - int256(0.5e18);
        fundingRate = imbalance * int256(0.01e18) / int256(1e18); // 基础费率 0.01%
    }
    
    /**
     * @dev 获取仓位统计信息
     * @param indexToken 指数代币地址
     * @return totalLongSizes 总做多仓位
     * @return totalShortSizes 总做空仓位
     * @return longShortRatio 多空比例
     */
    function getPositionStats(address indexToken) external view returns (
        uint256 totalLongSizes,
        uint256 totalShortSizes,
        uint256 longShortRatio
    ) {
        Config memory config = configs[indexToken];
        totalLongSizes = config.totalLongSizes;
        totalShortSizes = config.totalShortSizes;
        
        uint256 totalSizes = totalLongSizes + totalShortSizes;
        if (totalSizes > 0) {
            longShortRatio = totalLongSizes.mulDiv(1e18, totalSizes);
        }
    }
}
```

## 实现步骤

### 第一步：部署基础合约

1. **部署 VAMM 合约**
   ```solidity
   // 部署脚本示例
   VAMM vamm = new VAMM();
   ```

2. **部署 Vault 合约**
   ```solidity
   Vault vault = new Vault();
   ```

3. **部署 MarketRouter 合约**
   ```solidity
   MarketRouter router = new MarketRouter();
   ```

4. **部署 PositionsTracker 合约**
   ```solidity
   PositionsTracker tracker = new PositionsTracker();
   ```

### 第二步：初始化合约

```solidity
// 初始化 VAMM
vamm.initialize(
    address(vault),
    address(tracker),
    address(router),
    address(orderBook),
    controller
);

// 初始化 Vault
vault.initialize(
    stableToken,
    address(vamm),
    lpManager,
    priceFeed,
    address(tracker),
    address(router),
    controller,
    utilityStorage,
    liquidityManager
);
```

### 第三步：配置交易对

```solidity
// 配置 BTC/USD 交易对
vamm.setTokenConfig(
    btcToken,
    1000e18,    // 初始 BTC 数量
    50000000e18, // 初始 USD 数量 (价格 = 50000)
    50000e18    // 参考价格
);

// 配置仓位限制
tracker.setTokenConfig(
    btcToken,
    10000000e18, // 最大做多仓位
    10000000e18  // 最大做空仓位
);
```

### 第四步：测试交易流程

```solidity
// 用户开多仓
router.increasePosition(
    btcToken,
    1000e18,  // 1000 USDC 保证金
    10000e18, // 10000 USDC 仓位规模 (10倍杠杆)
    true      // 做多
);

// 用户平仓
router.decreasePosition(
    btcToken,
    500e18,   // 提取 500 USDC 保证金
    5000e18,  // 平掉 5000 USDC 仓位
    true      // 做多
);
```

## 关键特性说明

### 1. 虚拟流动性机制

- **恒定乘积公式**：`x * y = k`，其中 x 是指数代币数量，y 是稳定币数量
- **价格计算**：`price = y / x`
- **滑点控制**：通过调整虚拟流动性 k 值来控制滑点

### 2. 杠杆实现

- **保证金交易**：用户只需提供部分保证金即可开启大额仓位
- **杠杆计算**：`leverage = position_size / collateral`
- **风险控制**：设置最大杠杆限制和强制平仓机制

### 3. 资金费率机制

- **平衡多空**：通过资金费率激励平衡多空仓位
- **费率计算**：基于多空仓位比例动态调整
- **支付方向**：仓位占优方支付给仓位劣势方

### 4. 清算机制

- **清算条件**：当仓位亏损接近保证金时触发清算
- **清算激励**：给予清算者一定比例的清算费用
- **部分清算**：支持部分清算以降低系统风险

## 安全考虑

### 1. 价格操纵防护

```solidity
// 价格偏差检查
function validatePriceDeviation(
    uint256 newPrice,
    uint256 referencePrice
) internal view {
    uint256 deviation = newPrice > referencePrice 
        ? (newPrice - referencePrice) * 10000 / referencePrice
        : (referencePrice - newPrice) * 10000 / referencePrice;
    
    require(deviation <= maxAllowedDeviation, "Price deviation too high");
}
```

### 2. 重入攻击防护

```solidity
// 使用 ReentrancyGuard
contract MarketRouter is ReentrancyGuard {
    function increasePosition(...) external nonReentrant {
        // 交易逻辑
    }
}
```

### 3. 整数溢出防护

```solidity
// 使用 SafeMath 或 Solidity 0.8+ 内置检查
using Math for uint256;

function calculatePnL(uint256 size, uint256 price) internal pure returns (uint256) {
    return size.mulDiv(price, 1e18);
}
```

## 前端集成示例

### 1. 连接钱包和合约

```typescript
import { ethers } from 'ethers';
import { useWallet } from '@/hooks/useWallet';

const MarketRouterABI = [...]; // 合约 ABI
const VAMM_ABI = [...]; // VAMM ABI

export function useLeverageDEX() {
  const { signer, address } = useWallet();
  
  const marketRouter = new ethers.Contract(
    MARKET_ROUTER_ADDRESS,
    MarketRouterABI,
    signer
  );
  
  const vamm = new ethers.Contract(
    VAMM_ADDRESS,
    VAMM_ABI,
    signer
  );
  
  return { marketRouter, vamm };
}
```

### 2. 开仓交易

```typescript
/**
 * 开仓交易
 * @param indexToken 指数代币地址
 * @param collateral 保证金数量
 * @param size 仓位规模
 * @param isLong 是否做多
 */
export async function openPosition(
  indexToken: string,
  collateral: string,
  size: string,
  isLong: boolean
) {
  const { marketRouter } = useLeverageDEX();
  
  try {
    // 预估 gas
    const gasEstimate = await marketRouter.estimateGas.increasePosition(
      indexToken,
      ethers.utils.parseEther(collateral),
      ethers.utils.parseEther(size),
      isLong
    );
    
    // 执行交易
    const tx = await marketRouter.increasePosition(
      indexToken,
      ethers.utils.parseEther(collateral),
      ethers.utils.parseEther(size),
      isLong,
      {
        gasLimit: gasEstimate.mul(120).div(100) // 增加 20% gas buffer
      }
    );
    
    // 等待确认
    const receipt = await tx.wait();
    console.log('Position opened:', receipt.transactionHash);
    
    return receipt;
  } catch (error) {
    console.error('Failed to open position:', error);
    throw error;
  }
}
```

### 3. 获取仓位信息

```typescript
/**
 * 获取用户仓位信息
 * @param user 用户地址
 * @param indexToken 指数代币地址
 * @param isLong 是否做多
 */
export async function getPosition(
  user: string,
  indexToken: string,
  isLong: boolean
) {
  const { vault } = useLeverageDEX();
  
  try {
    // 计算仓位键
    const positionKey = ethers.utils.keccak256(
      ethers.utils.defaultAbiCoder.encode(
        ['address', 'address', 'bool'],
        [user, indexToken, isLong]
      )
    );
    
    // 获取仓位数据
    const position = await vault.positions(positionKey);
    
    return {
      size: ethers.utils.formatEther(position.size),
      collateral: ethers.utils.formatEther(position.collateral),
      entryPrice: ethers.utils.formatEther(position.entryPrice),
      lastUpdateTime: position.lastUpdateTime.toNumber(),
      isLong: position.long
    };
  } catch (error) {
    console.error('Failed to get position:', error);
    throw error;
  }
}
```

### 4. 实时价格监听

```typescript
/**
 * 监听价格变化
 * @param indexToken 指数代币地址
 * @param callback 价格变化回调
 */
export function subscribeToPrice(
  indexToken: string,
  callback: (price: string) => void
) {
  const { vamm } = useLeverageDEX();
  
  // 定期查询价格
  const interval = setInterval(async () => {
    try {
      const price = await vamm.getPrice(indexToken);
      callback(ethers.utils.formatEther(price));
    } catch (error) {
      console.error('Failed to get price:', error);
    }
  }, 1000); // 每秒更新一次
  
  // 返回清理函数
  return () => clearInterval(interval);
}
```

## 总结

通过本指南，你已经学会了如何实现一个基于 vAMM 的杠杆 DEX。关键要点包括：

1. **vAMM 机制**：使用虚拟流动性池进行价格发现
2. **杠杆交易**：通过保证金实现多倍杠杆
3. **风险管理**：清算机制和资金费率平衡
4. **安全考虑**：防止价格操纵和重入攻击
5. **前端集成**：提供完整的用户交互界面

这个实现为学习 DeFi 协议提供了一个完整的参考，你可以在此基础上添加更多功能，如订单簿、流动性挖矿等。

## 进阶功能扩展

### 1. 订单簿集成
- 限价单和市价单支持
- 订单匹配引擎
- 订单取消和修改

### 2. 流动性挖矿
- LP 代币奖励
- 交易挖矿激励
- 治理代币分发

### 3. 跨链支持
- 多链部署
- 跨链桥接
- 统一流动性池

### 4. 高级风控
- 动态杠杆调整
- 风险评分系统
- 自动止损止盈

继续学习和实践，你将能够构建更加完善和安全的 DeFi 协议！