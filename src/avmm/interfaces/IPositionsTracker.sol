// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IPositionsTracker Interface
 * @dev 仓位跟踪和资金费率接口
 */
interface IPositionsTracker {
    // 事件
    event FundingRateUpdated(address indexed token, int256 fundingRate);
    event PositionUpdated(
        address indexed user,
        address indexed token,
        bool long,
        uint256 size,
        int256 fundingPayment
    );
    
    // 配置结构体
    struct Config {
        uint256 fundingRateFactor;      // 资金费率因子
        uint256 stableFundingRateFactor; // 稳定资金费率因子
        uint256 maxFundingRate;         // 最大资金费率
        uint256 fundingInterval;        // 资金费率更新间隔
        bool enabled;                   // 是否启用
    }
    
    // 视图函数
    function configs(address token) external view returns (
        uint256 fundingRateFactor,
        uint256 stableFundingRateFactor,
        uint256 maxFundingRate,
        uint256 fundingInterval,
        bool enabled
    );
    
    function cumulativeFundingRates(address token, bool long) external view returns (int256);
    function lastFundingTimes(address token) external view returns (uint256);
    function globalShortSizes(address token) external view returns (uint256);
    function globalLongSizes(address token) external view returns (uint256);
    
    // 核心功能函数
    function updateFundingRate(address token) external;
    
    function updatePosition(
        address user,
        address token,
        bool long,
        uint256 sizeDelta,
        bool increase
    ) external;
    
    function getFundingFee(
        address user,
        address token,
        bool long,
        uint256 size
    ) external view returns (int256);
    
    function getCurrentFundingRate(address token) external view returns (int256);
    
    // 管理函数
    function setTokenConfig(
        address token,
        uint256 fundingRateFactor,
        uint256 stableFundingRateFactor,
        uint256 maxFundingRate,
        uint256 fundingInterval
    ) external;
    
    function deleteTokenConfig(address token) external;
}