// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IMarketRouter Interface
 * @dev 交易路由接口
 */
interface IMarketRouter {
    // 事件
    event PositionIncreased(
        address indexed user,
        address indexed indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool long
    );
    
    event PositionDecreased(
        address indexed user,
        address indexed indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool long
    );
    
    event PositionLiquidated(
        address indexed user,
        address indexed indexToken,
        uint256 sizeDelta,
        bool long,
        address indexed liquidator
    );
    
    // 视图函数
    function vault() external view returns (address);
    function VAMM() external view returns (address);
    function stable() external view returns (address);
    function whitelistedToken(address token) external view returns (bool);
    function liquidators(address liquidator) external view returns (bool);
    function MIN_POSITION_WORTH() external view returns (uint256);
    
    // 核心功能函数
    function increasePosition(
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool long
    ) external;
    
    function decreasePosition(
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool long
    ) external;
    
    function liquidatePosition(
        address user,
        address indexToken,
        uint256 sizeDelta,
        bool long
    ) external;
    
    // 管理函数
    function setTokenConfig(address indexToken, bool enabled) external;
    function setLiquidator(address liquidator, bool enabled) external;
}