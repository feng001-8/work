// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IVault.sol";
import "./interfaces/IVAMM.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Vault - 资金和仓位管理合约
 * @dev 管理用户保证金、仓位和借贷
 */
contract Vault is IVault, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    // 最大杠杆倍数
    uint256 public constant MAX_LEVERAGE = 50;
    // 清算阈值（90%）
    uint256 public constant LIQUIDATION_THRESHOLD = 9000;
    // 清算费用（0.5%）
    uint256 public constant LIQUIDATION_FEE = 50;
    
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
    
    // 修饰符
    modifier onlyVAMM() {
        require(msg.sender == VAMM, "Vault: caller is not VAMM");
        _;
    }
    
    modifier onlyWhitelistedToken(address token) {
        require(whitelistedToken[token], "Vault: token not whitelisted");
        _;
    }
    
    constructor() {
        _transferOwnership(msg.sender);
    }
    
    /**
     * @dev 初始化合约
     * @param _stable 稳定币地址
     * @param _VAMM VAMM 合约地址
     */
    function initialize(address _stable, address _VAMM) external onlyOwner {
        require(_stable != address(0), "Vault: invalid stable address");
        require(_VAMM != address(0), "Vault: invalid VAMM address");
        
        stable = _stable;
        VAMM = _VAMM;
    }
    
    /**
     * @dev 设置代币白名单
     * @param token 代币地址
     * @param enabled 是否启用
     */
    function setTokenConfig(address token, bool enabled) external onlyOwner {
        whitelistedToken[token] = enabled;
    }
    
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
    ) external onlyVAMM onlyWhitelistedToken(indexToken) nonReentrant {
        require(user != address(0), "Vault: invalid user address");
        require(sizeDelta > 0, "Vault: invalid size delta");
        require(markPrice > 0, "Vault: invalid mark price");
        
        bytes32 key = getPositionKey(user, indexToken, long);
        Position storage position = positions[key];
        
        // 收取保证金
        if (collateralDelta > 0) {
            IERC20(stable).safeTransferFrom(user, address(this), collateralDelta);
        }
        
        // 更新仓位
        if (position.size == 0) {
            // 新开仓位
            position.entryPrice = markPrice;
            position.long = long;
        } else {
            // 加仓，重新计算平均开仓价格
            uint256 totalSize = position.size + sizeDelta;
            position.entryPrice = (position.size * position.entryPrice + sizeDelta * markPrice) / totalSize;
        }
        
        position.size += sizeDelta;
        position.collateral += collateralDelta;
        position.lastUpdateTime = block.timestamp;
        
        // 验证杠杆率
        _validateLeverage(position.size, position.collateral);
        
        emit PositionIncreased(user, indexToken, collateralDelta, sizeDelta, long, markPrice);
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
    ) external onlyVAMM onlyWhitelistedToken(indexToken) nonReentrant {
        require(user != address(0), "Vault: invalid user address");
        require(sizeDelta > 0, "Vault: invalid size delta");
        require(markPrice > 0, "Vault: invalid mark price");
        
        bytes32 key = getPositionKey(user, indexToken, long);
        Position storage position = positions[key];
        
        require(position.size >= sizeDelta, "Vault: insufficient position size");
        
        // 计算盈亏
        (uint256 pnl, bool hasProfit) = calculatePnL(
            position.size,
            position.entryPrice,
            markPrice,
            long
        );
        
        // 按比例计算本次平仓的盈亏
        uint256 proportionalPnL = pnl * sizeDelta / position.size;
        uint256 proportionalCollateral = position.collateral * sizeDelta / position.size;
        
        // 更新仓位
        position.size -= sizeDelta;
        position.collateral -= proportionalCollateral;
        
        uint256 collateralToReturn = collateralDelta;
        
        if (hasProfit) {
            // 盈利情况
            collateralToReturn = proportionalCollateral + proportionalPnL;
        } else {
            // 亏损情况
            if (proportionalPnL >= proportionalCollateral) {
                // 保证金不足以覆盖亏损
                collateralToReturn = 0;
            } else {
                collateralToReturn = proportionalCollateral - proportionalPnL;
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
        
        emit PositionDecreased(user, indexToken, collateralDelta, sizeDelta, long, markPrice);
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
    ) external onlyVAMM onlyWhitelistedToken(indexToken) nonReentrant {
        require(user != address(0), "Vault: invalid user address");
        require(sizeDelta > 0, "Vault: invalid size delta");
        require(feeReceiver != address(0), "Vault: invalid fee receiver");
        
        bytes32 key = getPositionKey(user, indexToken, long);
        Position storage position = positions[key];
        
        require(position.size >= sizeDelta, "Vault: insufficient position size");
        
        // 验证是否可以清算
        require(isLiquidatable(user, indexToken, long), "Vault: position not liquidatable");
        
        // 计算清算费用
        uint256 liquidationFee = sizeDelta * LIQUIDATION_FEE / 10000;
        uint256 proportionalCollateral = position.collateral * sizeDelta / position.size;
        
        // 更新仓位
        position.size -= sizeDelta;
        position.collateral -= proportionalCollateral;
        
        if (proportionalCollateral > liquidationFee) {
            // 支付清算费用给清算者
            IERC20(stable).safeTransfer(feeReceiver, liquidationFee);
            // 剩余保证金返还给用户
            uint256 remainingCollateral = proportionalCollateral - liquidationFee;
            if (remainingCollateral > 0) {
                IERC20(stable).safeTransfer(user, remainingCollateral);
            }
        } else {
            // 保证金不足以支付清算费用，全部给清算者
            IERC20(stable).safeTransfer(feeReceiver, proportionalCollateral);
        }
        
        // 如果仓位完全清算，删除记录
        if (position.size == 0) {
            delete positions[key];
        }
        
        emit PositionLiquidated(user, indexToken, sizeDelta, long, feeReceiver);
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
    function calculatePnL(
        uint256 size,
        uint256 entryPrice,
        uint256 markPrice,
        bool long
    ) public pure returns (uint256 pnl, bool hasProfit) {
        require(size > 0, "Vault: invalid size");
        require(entryPrice > 0, "Vault: invalid entry price");
        require(markPrice > 0, "Vault: invalid mark price");
        
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
     * @dev 检查仓位是否可以清算
     * @param user 用户地址
     * @param indexToken 指数代币地址
     * @param long 是否做多
     * @return 是否可以清算
     */
    function isLiquidatable(
        address user,
        address indexToken,
        bool long
    ) public view returns (bool) {
        bytes32 key = getPositionKey(user, indexToken, long);
        Position memory position = positions[key];
        
        if (position.size == 0) {
            return false;
        }
        
        uint256 markPrice = IVAMM(VAMM).getPrice(indexToken);
        
        (uint256 pnl, bool hasProfit) = calculatePnL(
            position.size,
            position.entryPrice,
            markPrice,
            position.long
        );
        
        if (hasProfit) {
            return false;
        }
        
        // 如果亏损超过保证金的90%，则可以清算
        return pnl >= position.collateral * LIQUIDATION_THRESHOLD / 10000;
    }
    
    /**
     * @dev 生成仓位键
     * @param user 用户地址
     * @param indexToken 指数代币地址
     * @param long 是否做多
     * @return 仓位键
     */
    function getPositionKey(
        address user,
        address indexToken,
        bool long
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, indexToken, long));
    }
    
    /**
     * @dev 验证杠杆率
     * @param size 仓位规模
     * @param collateral 保证金
     */
    function _validateLeverage(uint256 size, uint256 collateral) internal pure {
        require(collateral > 0, "Vault: zero collateral");
        uint256 leverage = size * 1e18 / collateral;
        require(leverage <= MAX_LEVERAGE * 1e18, "Vault: leverage too high");
    }
    
    /**
     * @dev 紧急提取（仅所有者）
     * @param token 代币地址
     * @param amount 提取数量
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }
}