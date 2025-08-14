// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IMarketRouter.sol";
import "./interfaces/IVAMM.sol";
import "./interfaces/IVault.sol";
import "./MockUSDC.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title VAMMExample - vAMM 使用示例合约
 * @dev 展示如何与 vAMM 杠杆交易系统交互
 */
contract VAMMExample {
    using SafeERC20 for IERC20;
    
    // 合约地址
    address public marketRouter;
    address public vamm;
    address public vault;
    address public usdc;
    
    // 事件
    event TradeExecuted(
        address indexed user,
        address indexed token,
        uint256 collateral,
        uint256 size,
        bool long,
        bool increase
    );
    
    constructor(
        address _marketRouter,
        address _vamm,
        address _vault,
        address _usdc
    ) {
        marketRouter = _marketRouter;
        vamm = _vamm;
        vault = _vault;
        usdc = _usdc;
    }
    
    /**
     * @dev 开多仓示例
     * @param token 交易代币地址
     * @param collateralAmount 保证金数量
     * @param leverage 杠杆倍数
     */
    function openLongPosition(
        address token,
        uint256 collateralAmount,
        uint256 leverage
    ) external {
        require(collateralAmount > 0, "VAMMExample: invalid collateral");
        require(leverage > 0 && leverage <= 50, "VAMMExample: invalid leverage");
        
        // 计算仓位大小
        uint256 positionSize = collateralAmount * leverage;
        
        // 从用户转入 USDC
        IERC20(usdc).safeTransferFrom(msg.sender, address(this), collateralAmount);
        
        // 批准 MarketRouter 使用 USDC
        IERC20(usdc).safeApprove(marketRouter, collateralAmount);
        
        // 开多仓
        IMarketRouter(marketRouter).increasePosition(
            token,
            collateralAmount,
            positionSize,
            true // long
        );
        
        emit TradeExecuted(msg.sender, token, collateralAmount, positionSize, true, true);
    }
    
    /**
     * @dev 开空仓示例
     * @param token 交易代币地址
     * @param collateralAmount 保证金数量
     * @param leverage 杠杆倍数
     */
    function openShortPosition(
        address token,
        uint256 collateralAmount,
        uint256 leverage
    ) external {
        require(collateralAmount > 0, "VAMMExample: invalid collateral");
        require(leverage > 0 && leverage <= 50, "VAMMExample: invalid leverage");
        
        // 计算仓位大小
        uint256 positionSize = collateralAmount * leverage;
        
        // 从用户转入 USDC
        IERC20(usdc).safeTransferFrom(msg.sender, address(this), collateralAmount);
        
        // 批准 MarketRouter 使用 USDC
        IERC20(usdc).safeApprove(marketRouter, collateralAmount);
        
        // 开空仓
        IMarketRouter(marketRouter).increasePosition(
            token,
            collateralAmount,
            positionSize,
            false // short
        );
        
        emit TradeExecuted(msg.sender, token, collateralAmount, positionSize, false, true);
    }
    
    /**
     * @dev 平仓示例
     * @param token 交易代币地址
     * @param sizeToClose 要平仓的大小
     * @param long 是否为多仓
     */
    function closePosition(
        address token,
        uint256 sizeToClose,
        bool long
    ) external {
        require(sizeToClose > 0, "VAMMExample: invalid size");
        
        // 获取用户当前仓位
        (uint256 currentSize, uint256 collateral, , , ) = IMarketRouter(marketRouter).getPosition(
            msg.sender,
            token,
            long
        );
        
        require(currentSize >= sizeToClose, "VAMMExample: insufficient position size");
        
        // 计算要提取的保证金比例
        uint256 collateralToWithdraw = collateral * sizeToClose / currentSize;
        
        // 平仓
        IMarketRouter(marketRouter).decreasePosition(
            token,
            collateralToWithdraw,
            sizeToClose,
            long
        );
        
        emit TradeExecuted(msg.sender, token, collateralToWithdraw, sizeToClose, long, false);
    }
    
    /**
     * @dev 获取仓位信息
     * @param user 用户地址
     * @param token 代币地址
     * @param long 是否为多仓
     * @return 仓位信息
     */
    function getPositionInfo(
        address user,
        address token,
        bool long
    ) external view returns (
        uint256 size,
        uint256 collateral,
        uint256 entryPrice,
        uint256 markPrice,
        int256 pnl,
        bool hasProfit,
        uint256 leverage
    ) {
        // 获取仓位基本信息
        (size, collateral, entryPrice, , ) = IMarketRouter(marketRouter).getPosition(user, token, long);
        
        if (size == 0) {
            return (0, 0, 0, 0, 0, false, 0);
        }
        
        // 获取当前标记价格
        markPrice = IVAMM(vamm).getPrice(token);
        
        // 获取盈亏
        (uint256 pnlAbs, bool profit) = IMarketRouter(marketRouter).getPositionPnL(user, token, long);
        pnl = profit ? int256(pnlAbs) : -int256(pnlAbs);
        hasProfit = profit;
        
        // 计算杠杆倍数
        leverage = size * 1e18 / collateral;
    }
    
    /**
     * @dev 获取交易价格影响
     * @param token 代币地址
     * @param size 交易大小
     * @param long 是否做多
     * @return currentPrice 当前价格
     * @return newPrice 交易后价格
     * @return priceImpact 价格影响（基点）
     */
    function getTradeImpact(
        address token,
        uint256 size,
        bool long
    ) external view returns (
        uint256 currentPrice,
        uint256 newPrice,
        uint256 priceImpact
    ) {
        currentPrice = IVAMM(vamm).getPrice(token);
        (newPrice, priceImpact) = IMarketRouter(marketRouter).getPriceImpact(
            token,
            size,
            true, // increase
            long
        );
    }
    
    /**
     * @dev 批量交易示例
     * @param tokens 代币地址数组
     * @param collaterals 保证金数组
     * @param leverages 杠杆数组
     * @param longs 做多标志数组
     */
    function batchTrade(
        address[] calldata tokens,
        uint256[] calldata collaterals,
        uint256[] calldata leverages,
        bool[] calldata longs
    ) external {
        require(
            tokens.length == collaterals.length &&
            collaterals.length == leverages.length &&
            leverages.length == longs.length,
            "VAMMExample: array length mismatch"
        );
        
        uint256 totalCollateral = 0;
        for (uint256 i = 0; i < collaterals.length; i++) {
            totalCollateral += collaterals[i];
        }
        
        // 一次性转入所有保证金
        IERC20(usdc).safeTransferFrom(msg.sender, address(this), totalCollateral);
        IERC20(usdc).safeApprove(marketRouter, totalCollateral);
        
        // 执行批量交易
        for (uint256 i = 0; i < tokens.length; i++) {
            require(leverages[i] > 0 && leverages[i] <= 50, "VAMMExample: invalid leverage");
            
            uint256 positionSize = collaterals[i] * leverages[i];
            
            IMarketRouter(marketRouter).increasePosition(
                tokens[i],
                collaterals[i],
                positionSize,
                longs[i]
            );
            
            emit TradeExecuted(msg.sender, tokens[i], collaterals[i], positionSize, longs[i], true);
        }
    }
    
    /**
     * @dev 模拟交易（不实际执行）
     * @param token 代币地址
     * @param collateralAmount 保证金数量
     * @param leverage 杠杆倍数
     * @param long 是否做多
     * @return expectedPrice 预期执行价格
     * @return priceImpact 价格影响
     * @return liquidationPrice 清算价格
     */
    function simulateTrade(
        address token,
        uint256 collateralAmount,
        uint256 leverage,
        bool long
    ) external view returns (
        uint256 expectedPrice,
        uint256 priceImpact,
        uint256 liquidationPrice
    ) {
        uint256 positionSize = collateralAmount * leverage;
        
        // 获取预期执行价格
        (, , expectedPrice) = IVAMM(vamm).preCalculatePrice(
            token,
            positionSize,
            true, // increase
            long
        );
        
        // 计算价格影响
        uint256 currentPrice = IVAMM(vamm).getPrice(token);
        if (expectedPrice > currentPrice) {
            priceImpact = ((expectedPrice - currentPrice) * 10000) / currentPrice;
        } else {
            priceImpact = ((currentPrice - expectedPrice) * 10000) / currentPrice;
        }
        
        // 计算清算价格（简化计算，假设90%保证金损失时清算）
        uint256 maxLoss = collateralAmount * 90 / 100;
        uint256 lossPerUnit = maxLoss * expectedPrice / positionSize;
        
        if (long) {
            liquidationPrice = expectedPrice > lossPerUnit ? expectedPrice - lossPerUnit : 0;
        } else {
            liquidationPrice = expectedPrice + lossPerUnit;
        }
    }
    
    /**
     * @dev 紧急提取（仅用于测试）
     * @param token 代币地址
     * @param amount 提取数量
     */
    function emergencyWithdraw(address token, uint256 amount) external {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}