// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IMarketRouter.sol";
import "./interfaces/IVAMM.sol";
import "./interfaces/IVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title MarketRouter - 交易路由合约
 * @dev 处理用户交易请求和路由
 */
contract MarketRouter is IMarketRouter, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // 最小仓位价值
    uint256 public constant MIN_POSITION_WORTH = 10e18;
    
    address public vault;
    address public VAMM;
    address public stable;
    
    mapping(address => bool) public whitelistedToken;
    mapping(address => bool) public liquidators;
    
    // 修饰符
    modifier onlyWhitelistedToken(address token) {
        require(whitelistedToken[token], "MarketRouter: token not whitelisted");
        _;
    }
    
    modifier onlyLiquidator() {
        require(liquidators[msg.sender], "MarketRouter: not liquidator");
        _;
    }
    
    constructor() {
        _transferOwnership(msg.sender);
    }
    
    /**
     * @dev 初始化合约
     * @param _vault Vault 合约地址
     * @param _VAMM VAMM 合约地址
     * @param _stable 稳定币地址
     */
    function initialize(address _vault, address _VAMM, address _stable) external onlyOwner {
        require(_vault != address(0), "MarketRouter: invalid vault address");
        require(_VAMM != address(0), "MarketRouter: invalid VAMM address");
        require(_stable != address(0), "MarketRouter: invalid stable address");
        
        vault = _vault;
        VAMM = _VAMM;
        stable = _stable;
    }
    
    /**
     * @dev 设置代币白名单
     * @param indexToken 指数代币地址
     * @param enabled 是否启用
     */
    function setTokenConfig(address indexToken, bool enabled) external onlyOwner {
        whitelistedToken[indexToken] = enabled;
    }
    
    /**
     * @dev 设置清算者
     * @param liquidator 清算者地址
     * @param enabled 是否启用
     */
    function setLiquidator(address liquidator, bool enabled) external onlyOwner {
        liquidators[liquidator] = enabled;
    }
    
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
    ) external nonReentrant onlyWhitelistedToken(indexToken) {
        require(collateralDelta > 0, "MarketRouter: zero collateral");
        require(sizeDelta > 0, "MarketRouter: zero size");
        
        // 验证最小仓位价值
        require(sizeDelta >= MIN_POSITION_WORTH, "MarketRouter: position too small");
        
        // 预先批准稳定币转账
        IERC20(stable).safeTransferFrom(msg.sender, address(this), collateralDelta);
        IERC20(stable).safeApprove(vault, collateralDelta);
        
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
        
        emit PositionIncreased(msg.sender, indexToken, collateralDelta, sizeDelta, long);
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
    ) external nonReentrant onlyWhitelistedToken(indexToken) {
        require(sizeDelta > 0, "MarketRouter: zero size");
        
        // 验证用户是否有足够的仓位
        bytes32 positionKey = IVault(vault).getPositionKey(msg.sender, indexToken, long);
        (uint256 size, , , , ) = IVault(vault).positions(positionKey);
        require(size >= sizeDelta, "MarketRouter: insufficient position size");
        
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
        
        emit PositionDecreased(msg.sender, indexToken, collateralDelta, sizeDelta, long);
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
    ) external nonReentrant onlyLiquidator onlyWhitelistedToken(indexToken) {
        require(user != address(0), "MarketRouter: invalid user address");
        require(sizeDelta > 0, "MarketRouter: zero size");
        
        // 验证仓位是否可以清算
        require(IVault(vault).isLiquidatable(user, indexToken, long), "MarketRouter: position not liquidatable");
        
        // 验证用户是否有足够的仓位
        bytes32 positionKey = IVault(vault).getPositionKey(user, indexToken, long);
        (uint256 size, , , , ) = IVault(vault).positions(positionKey);
        require(size >= sizeDelta, "MarketRouter: insufficient position size");
        
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
        
        emit PositionLiquidated(user, indexToken, sizeDelta, long, msg.sender);
    }
    
    /**
     * @dev 批量清算仓位
     * @param users 被清算用户地址数组
     * @param indexTokens 指数代币地址数组
     * @param sizeDeltas 清算规模数组
     * @param longs 是否做多数组
     */
    function batchLiquidatePositions(
        address[] calldata users,
        address[] calldata indexTokens,
        uint256[] calldata sizeDeltas,
        bool[] calldata longs
    ) external onlyLiquidator {
        require(
            users.length == indexTokens.length &&
            indexTokens.length == sizeDeltas.length &&
            sizeDeltas.length == longs.length,
            "MarketRouter: array length mismatch"
        );
        
        for (uint256 i = 0; i < users.length; i++) {
            if (whitelistedToken[indexTokens[i]] && 
                IVault(vault).isLiquidatable(users[i], indexTokens[i], longs[i])) {
                
                bytes32 positionKey = IVault(vault).getPositionKey(users[i], indexTokens[i], longs[i]);
                (uint256 size, , , , ) = IVault(vault).positions(positionKey);
                
                if (size >= sizeDeltas[i]) {
                    IVAMM(VAMM).updateIndex(
                        users[i],
                        indexTokens[i],
                        0,
                        sizeDeltas[i],
                        longs[i],
                        false,
                        true,
                        msg.sender
                    );
                    
                    emit PositionLiquidated(users[i], indexTokens[i], sizeDeltas[i], longs[i], msg.sender);
                }
            }
        }
    }
    
    /**
     * @dev 获取仓位信息
     * @param user 用户地址
     * @param indexToken 指数代币地址
     * @param long 是否做多
     * @return size 仓位规模
     * @return collateral 保证金
     * @return entryPrice 开仓价格
     * @return lastUpdateTime 最后更新时间
     * @return isLong 是否做多
     */
    function getPosition(
        address user,
        address indexToken,
        bool long
    ) external view returns (
        uint256 size,
        uint256 collateral,
        uint256 entryPrice,
        uint256 lastUpdateTime,
        bool isLong
    ) {
        bytes32 positionKey = IVault(vault).getPositionKey(user, indexToken, long);
        return IVault(vault).positions(positionKey);
    }
    
    /**
     * @dev 获取仓位盈亏
     * @param user 用户地址
     * @param indexToken 指数代币地址
     * @param long 是否做多
     * @return pnl 盈亏金额
     * @return hasProfit 是否盈利
     */
    function getPositionPnL(
        address user,
        address indexToken,
        bool long
    ) external view returns (uint256 pnl, bool hasProfit) {
        bytes32 positionKey = IVault(vault).getPositionKey(user, indexToken, long);
        (uint256 size, , uint256 entryPrice, , bool isLong) = IVault(vault).positions(positionKey);
        
        if (size == 0) {
            return (0, false);
        }
        
        uint256 markPrice = IVAMM(VAMM).getPrice(indexToken);
        return IVault(vault).calculatePnL(size, entryPrice, markPrice, isLong);
    }
    
    /**
     * @dev 预计算交易后的价格影响
     * @param indexToken 指数代币地址
     * @param sizeDelta 交易规模变化
     * @param increase 是否增加仓位
     * @param long 是否做多
     * @return newPrice 新价格
     * @return priceImpact 价格影响
     */
    function getPriceImpact(
        address indexToken,
        uint256 sizeDelta,
        bool increase,
        bool long
    ) external view returns (uint256 newPrice, uint256 priceImpact) {
        uint256 currentPrice = IVAMM(VAMM).getPrice(indexToken);
        (, , uint256 markPrice) = IVAMM(VAMM).preCalculatePrice(indexToken, sizeDelta, increase, long);
        
        newPrice = markPrice;
        
        if (markPrice > currentPrice) {
            priceImpact = ((markPrice - currentPrice) * 10000) / currentPrice;
        } else {
            priceImpact = ((currentPrice - markPrice) * 10000) / currentPrice;
        }
    }
    
    /**
     * @dev 紧急暂停（仅所有者）
     */
    function pause() external onlyOwner {
        // 实现暂停逻辑
    }
    
    /**
     * @dev 恢复运行（仅所有者）
     */
    function unpause() external onlyOwner {
        // 实现恢复逻辑
    }
}