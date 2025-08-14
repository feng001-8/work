// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IVault Interface
 * @dev 资金和仓位管理接口
 */
interface IVault {
    // 事件
    event PositionIncreased(
        address indexed user,
        address indexed indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool long,
        uint256 markPrice
    );
    
    event PositionDecreased(
        address indexed user,
        address indexed indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool long,
        uint256 markPrice
    );
    
    event PositionLiquidated(
        address indexed user,
        address indexed indexToken,
        uint256 sizeDelta,
        bool long,
        address feeReceiver
    );
    
    // 仓位结构体
    struct Position {
        uint256 size;           // 仓位规模
        uint256 collateral;     // 保证金
        uint256 entryPrice;     // 开仓价格
        uint256 lastUpdateTime; // 最后更新时间
        bool long;              // 是否做多
    }
    
    // 视图函数
    function positions(bytes32 key) external view returns (
        uint256 size,
        uint256 collateral,
        uint256 entryPrice,
        uint256 lastUpdateTime,
        bool long
    );
    
    function whitelistedToken(address token) external view returns (bool);
    function stable() external view returns (address);
    function VAMM() external view returns (address);
    
    // 核心功能函数
    function increasePosition(
        address user,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool long,
        uint256 markPrice
    ) external;
    
    function decreasePosition(
        address user,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool long,
        uint256 markPrice
    ) external;
    
    function liquidatePosition(
        address user,
        address indexToken,
        uint256 sizeDelta,
        bool long,
        address feeReceiver
    ) external;
    
    function getPositionKey(
        address user,
        address indexToken,
        bool long
    ) external pure returns (bytes32);
    
    function calculatePnL(
        uint256 size,
        uint256 entryPrice,
        uint256 markPrice,
        bool long
    ) external pure returns (uint256 pnl, bool hasProfit);
    
    function isLiquidatable(
        address user,
        address indexToken,
        bool long
    ) external view returns (bool);
}