// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IVAMM Interface
 * @dev 虚拟自动做市商接口
 */
interface IVAMM {
    // 事件
    event TokenConfigSet(address indexed token, uint256 indexAmount, uint256 stableAmount);
    event TokenConfigDeleted(address indexed token);
    event PriceUpdated(address indexed token, uint256 newPrice);
    event LiquidityUpdated(address indexed token, uint256 newLiquidity);
    
    // 视图函数
    function allowedPriceDeviation() external view returns (uint256);
    function vault() external view returns (address);
    function positionsTracker() external view returns (address);
    function whitelistedToken(address token) external view returns (bool);
    function pairs(address token) external view returns (
        uint256 indexAmount,
        uint256 stableAmount,
        uint256 liquidity,
        uint256 lastUpdateTime
    );
    
    // 核心功能函数
    function setAllowedPriceDeviation(uint256 deviation) external;
    function setTokenConfig(
        address indexToken,
        uint256 indexAmount,
        uint256 stableAmount,
        uint256 referencePrice
    ) external;
    function deleteTokenConfig(address indexToken) external;
    
    function updateIndex(
        address user,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool long,
        bool increase,
        bool liquidation,
        address feeReceiver
    ) external;
    
    function setPrice(address indexToken, uint256 indexAmount, uint256 stableAmount) external;
    function setLiquidity(address indexToken, uint256 liquidity) external;
    
    function getData(address indexToken) external view returns (
        uint256 indexAmount,
        uint256 stableAmount,
        uint256 liquidity
    );
    
    function getPrice(address indexToken) external view returns (uint256);
    
    function preCalculatePrice(
        address indexToken,
        uint256 sizeDelta,
        bool increase,
        bool long
    ) external view returns (
        uint256 newStableAmount,
        uint256 newIndexAmount,
        uint256 markPrice
    );
}