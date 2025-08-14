// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IVAMM.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IPositionsTracker.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title VAMM - 虚拟自动做市商
 * @dev 实现基于恒定乘积公式的虚拟流动性池
 */
contract VAMM is IVAMM, Ownable, ReentrancyGuard {
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
    
    uint256 public allowedPriceDeviation = 50; // 0.5%
    address public vault;
    address public positionsTracker;
    
    // 修饰符
    modifier onlyVault() {
        require(msg.sender == vault, "VAMM: caller is not vault");
        _;
    }
    
    modifier onlyWhitelistedToken(address token) {
        require(whitelistedToken[token], "VAMM: token not whitelisted");
        _;
    }
    
    constructor() {
        _transferOwnership(msg.sender);
    }
    
    /**
     * @dev 初始化合约
     * @param _vault Vault 合约地址
     * @param _positionsTracker PositionsTracker 合约地址
     */
    function initialize(address _vault, address _positionsTracker) external onlyOwner {
        require(_vault != address(0), "VAMM: invalid vault address");
        require(_positionsTracker != address(0), "VAMM: invalid positions tracker address");
        
        vault = _vault;
        positionsTracker = _positionsTracker;
    }
    
    /**
     * @dev 设置允许的价格偏差
     * @param deviation 价格偏差 (基点，10000 = 100%)
     */
    function setAllowedPriceDeviation(uint256 deviation) external onlyOwner {
        require(deviation <= MAX_ALLOWED_PRICE_DEVIATION, "VAMM: deviation too high");
        allowedPriceDeviation = deviation;
    }
    
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
    ) external onlyOwner {
        require(indexToken != address(0), "VAMM: invalid token address");
        require(indexAmount > 0 && stableAmount > 0, "VAMM: invalid amounts");
        
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
        
        emit TokenConfigSet(indexToken, indexAmount, stableAmount);
    }
    
    /**
     * @dev 删除交易对配置
     * @param indexToken 指数代币地址
     */
    function deleteTokenConfig(address indexToken) external onlyOwner {
        require(whitelistedToken[indexToken], "VAMM: token not whitelisted");
        
        delete pairs[indexToken];
        whitelistedToken[indexToken] = false;
        
        emit TokenConfigDeleted(indexToken);
    }
    
    /**
     * @dev 获取当前标记价格
     * @param indexToken 指数代币地址
     * @return 标记价格 (稳定币/指数代币)
     */
    function getPrice(address indexToken) public view onlyWhitelistedToken(indexToken) returns (uint256) {
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
    ) public view onlyWhitelistedToken(indexToken) returns (
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
     * @param liquidation 是否为清算
     * @param feeReceiver 费用接收者
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
    ) external nonReentrant onlyWhitelistedToken(indexToken) {
        require(msg.sender == vault || owner() == msg.sender, "VAMM: unauthorized caller");
        
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
            
            // 验证价格偏差
            _validatePriceDeviation(indexToken, newIndexAmount, newStableAmount, getPrice(indexToken), false);
            
            // 更新虚拟池状态
            pair.stableAmount = newStableAmount;
            pair.indexAmount = newIndexAmount;
            pair.lastUpdateTime = block.timestamp;
            
            emit PriceUpdated(indexToken, markPrice);
        }
        
        // 更新仓位跟踪
        if (positionsTracker != address(0)) {
            IPositionsTracker(positionsTracker).updatePosition(
                user,
                indexToken,
                long,
                sizeDelta,
                increase
            );
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
     * @dev 设置价格（管理员功能）
     * @param indexToken 指数代币地址
     * @param indexAmount 指数代币数量
     * @param stableAmount 稳定币数量
     */
    function setPrice(address indexToken, uint256 indexAmount, uint256 stableAmount) external onlyOwner onlyWhitelistedToken(indexToken) {
        require(indexAmount > 0 && stableAmount > 0, "VAMM: invalid amounts");
        
        Pair storage pair = pairs[indexToken];
        pair.indexAmount = indexAmount;
        pair.stableAmount = stableAmount;
        pair.liquidity = indexAmount * stableAmount;
        pair.lastUpdateTime = block.timestamp;
        
        emit PriceUpdated(indexToken, getPrice(indexToken));
    }
    
    /**
     * @dev 设置流动性（管理员功能）
     * @param indexToken 指数代币地址
     * @param liquidity 新的流动性
     */
    function setLiquidity(address indexToken, uint256 liquidity) external onlyOwner onlyWhitelistedToken(indexToken) {
        require(liquidity >= MIN_LIQUIDITY, "VAMM: insufficient liquidity");
        
        Pair storage pair = pairs[indexToken];
        pair.liquidity = liquidity;
        pair.lastUpdateTime = block.timestamp;
        
        emit LiquidityUpdated(indexToken, liquidity);
    }
    
    /**
     * @dev 获取交易对数据
     * @param indexToken 指数代币地址
     * @return indexAmount 指数代币数量
     * @return stableAmount 稳定币数量
     * @return liquidity 流动性
     */
    function getData(address indexToken) external view onlyWhitelistedToken(indexToken) returns (
        uint256 indexAmount,
        uint256 stableAmount,
        uint256 liquidity
    ) {
        Pair memory pair = pairs[indexToken];
        return (pair.indexAmount, pair.stableAmount, pair.liquidity);
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