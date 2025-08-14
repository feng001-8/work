// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IPositionsTracker.sol";
import "./interfaces/IVAMM.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title PositionsTracker - 仓位跟踪和资金费率合约
 * @dev 管理全局仓位数据和资金费率计算
 */
contract PositionsTracker is IPositionsTracker, Ownable, ReentrancyGuard {
    using Math for uint256;
    using SignedMath for int256;
    
    // 最大资金费率持续时间
    uint256 public constant MAX_DELTA_DURATION = 24 hours;
    // 最大流动性偏差
    uint256 public constant MAX_LIQUIDITY_DEVIATION = 1000; // 10%
    
    // 配置结构体
    struct Config {
        uint256 fundingRateFactor;      // 资金费率因子
        uint256 stableFundingRateFactor; // 稳定资金费率因子
        uint256 maxFundingRate;         // 最大资金费率
        uint256 fundingInterval;        // 资金费率更新间隔
        bool enabled;                   // 是否启用
    }
    
    // 用户仓位资金费率记录
    struct UserFundingData {
        int256 entryFundingRate;        // 进入时的累计资金费率
        uint256 lastUpdateTime;        // 最后更新时间
    }
    
    // 状态变量
    mapping(address => Config) public configs;
    mapping(address => mapping(bool => int256)) public cumulativeFundingRates; // token => long => rate
    mapping(address => uint256) public lastFundingTimes;
    mapping(address => uint256) public globalShortSizes;
    mapping(address => uint256) public globalLongSizes;
    mapping(bytes32 => UserFundingData) public userFundingData; // userPositionKey => data
    
    address public VAMM;
    address public vault;
    
    // 修饰符
    modifier onlyVAMM() {
        require(msg.sender == VAMM, "PositionsTracker: caller is not VAMM");
        _;
    }
    
    modifier onlyEnabledToken(address token) {
        require(configs[token].enabled, "PositionsTracker: token not enabled");
        _;
    }
    
    constructor() {
        _transferOwnership(msg.sender);
    }
    
    /**
     * @dev 初始化合约
     * @param _VAMM VAMM 合约地址
     * @param _vault Vault 合约地址
     */
    function initialize(address _VAMM, address _vault) external onlyOwner {
        require(_VAMM != address(0), "PositionsTracker: invalid VAMM address");
        require(_vault != address(0), "PositionsTracker: invalid vault address");
        
        VAMM = _VAMM;
        vault = _vault;
    }
    
    /**
     * @dev 设置代币配置
     * @param token 代币地址
     * @param fundingRateFactor 资金费率因子
     * @param stableFundingRateFactor 稳定资金费率因子
     * @param maxFundingRate 最大资金费率
     * @param fundingInterval 资金费率更新间隔
     */
    function setTokenConfig(
        address token,
        uint256 fundingRateFactor,
        uint256 stableFundingRateFactor,
        uint256 maxFundingRate,
        uint256 fundingInterval
    ) external onlyOwner {
        require(token != address(0), "PositionsTracker: invalid token address");
        require(fundingInterval > 0, "PositionsTracker: invalid funding interval");
        
        Config storage config = configs[token];
        config.fundingRateFactor = fundingRateFactor;
        config.stableFundingRateFactor = stableFundingRateFactor;
        config.maxFundingRate = maxFundingRate;
        config.fundingInterval = fundingInterval;
        config.enabled = true;
        
        // 初始化最后更新时间
        if (lastFundingTimes[token] == 0) {
            lastFundingTimes[token] = block.timestamp;
        }
    }
    
    /**
     * @dev 删除代币配置
     * @param token 代币地址
     */
    function deleteTokenConfig(address token) external onlyOwner {
        delete configs[token];
        delete lastFundingTimes[token];
        delete globalShortSizes[token];
        delete globalLongSizes[token];
        delete cumulativeFundingRates[token][true];
        delete cumulativeFundingRates[token][false];
    }
    
    /**
     * @dev 更新资金费率
     * @param token 代币地址
     */
    function updateFundingRate(address token) public onlyEnabledToken(token) {
        Config memory config = configs[token];
        uint256 lastTime = lastFundingTimes[token];
        
        if (block.timestamp <= lastTime + config.fundingInterval) {
            return; // 还未到更新时间
        }
        
        // 计算当前资金费率
        int256 fundingRate = getCurrentFundingRate(token);
        
        // 更新累计资金费率
        uint256 timeElapsed = block.timestamp - lastTime;
        int256 fundingRateIncrement = fundingRate * int256(timeElapsed) / int256(config.fundingInterval);
        
        cumulativeFundingRates[token][true] += fundingRateIncrement;
        cumulativeFundingRates[token][false] -= fundingRateIncrement; // 空头支付相反的费率
        
        lastFundingTimes[token] = block.timestamp;
        
        emit FundingRateUpdated(token, fundingRate);
    }
    
    /**
     * @dev 更新仓位
     * @param user 用户地址
     * @param token 代币地址
     * @param long 是否做多
     * @param sizeDelta 仓位变化
     * @param increase 是否增加仓位
     */
    function updatePosition(
        address user,
        address token,
        bool long,
        uint256 sizeDelta,
        bool increase
    ) external onlyVAMM onlyEnabledToken(token) nonReentrant {
        // 更新资金费率
        updateFundingRate(token);
        
        // 更新全局仓位大小
        if (increase) {
            if (long) {
                globalLongSizes[token] += sizeDelta;
            } else {
                globalShortSizes[token] += sizeDelta;
            }
        } else {
            if (long) {
                globalLongSizes[token] = globalLongSizes[token] > sizeDelta ? 
                    globalLongSizes[token] - sizeDelta : 0;
            } else {
                globalShortSizes[token] = globalShortSizes[token] > sizeDelta ? 
                    globalShortSizes[token] - sizeDelta : 0;
            }
        }
        
        // 更新用户资金费率记录
        bytes32 userKey = _getUserPositionKey(user, token, long);
        UserFundingData storage userData = userFundingData[userKey];
        
        if (increase) {
            // 开仓或加仓时记录当前累计资金费率
            userData.entryFundingRate = cumulativeFundingRates[token][long];
            userData.lastUpdateTime = block.timestamp;
        }
        
        emit PositionUpdated(user, token, long, sizeDelta, 0);
    }
    
    /**
     * @dev 获取资金费用
     * @param user 用户地址
     * @param token 代币地址
     * @param long 是否做多
     * @param size 仓位大小
     * @return 资金费用（正数表示需要支付，负数表示可以收取）
     */
    function getFundingFee(
        address user,
        address token,
        bool long,
        uint256 size
    ) external view onlyEnabledToken(token) returns (int256) {
        if (size == 0) {
            return 0;
        }
        
        bytes32 userKey = _getUserPositionKey(user, token, long);
        UserFundingData memory userData = userFundingData[userKey];
        
        int256 currentCumulativeRate = cumulativeFundingRates[token][long];
        int256 rateDiff = currentCumulativeRate - userData.entryFundingRate;
        
        return rateDiff * int256(size) / 1e18;
    }
    
    /**
     * @dev 获取当前资金费率
     * @param token 代币地址
     * @return 当前资金费率
     */
    function getCurrentFundingRate(address token) public view onlyEnabledToken(token) returns (int256) {
        Config memory config = configs[token];
        
        uint256 longSize = globalLongSizes[token];
        uint256 shortSize = globalShortSizes[token];
        uint256 totalSize = longSize + shortSize;
        
        if (totalSize == 0) {
            return 0;
        }
        
        // 计算多空不平衡比例
        int256 imbalance;
        if (longSize > shortSize) {
            imbalance = int256((longSize - shortSize) * 1e18 / totalSize);
        } else {
            imbalance = -int256((shortSize - longSize) * 1e18 / totalSize);
        }
        
        // 计算基础资金费率
        int256 baseFundingRate = imbalance * int256(config.fundingRateFactor) / 1e18;
        
        // 应用最大资金费率限制
        int256 maxRate = int256(config.maxFundingRate);
        if (baseFundingRate > maxRate) {
            baseFundingRate = maxRate;
        } else if (baseFundingRate < -maxRate) {
            baseFundingRate = -maxRate;
        }
        
        return baseFundingRate;
    }
    
    /**
     * @dev 获取全局仓位统计
     * @param token 代币地址
     * @return longSize 全局多头仓位大小
     * @return shortSize 全局空头仓位大小
     * @return longShortRatio 多空比例
     */
    function getGlobalPositions(address token) external view returns (
        uint256 longSize,
        uint256 shortSize,
        uint256 longShortRatio
    ) {
        longSize = globalLongSizes[token];
        shortSize = globalShortSizes[token];
        
        if (shortSize == 0) {
            longShortRatio = longSize > 0 ? type(uint256).max : 0;
        } else {
            longShortRatio = longSize * 1e18 / shortSize;
        }
    }
    
    /**
     * @dev 获取用户仓位资金费率数据
     * @param user 用户地址
     * @param token 代币地址
     * @param long 是否做多
     * @return entryFundingRate 进入时的累计资金费率
     * @return lastUpdateTime 最后更新时间
     */
    function getUserFundingData(
        address user,
        address token,
        bool long
    ) external view returns (int256 entryFundingRate, uint256 lastUpdateTime) {
        bytes32 userKey = _getUserPositionKey(user, token, long);
        UserFundingData memory userData = userFundingData[userKey];
        return (userData.entryFundingRate, userData.lastUpdateTime);
    }
    
    /**
     * @dev 生成用户仓位键
     * @param user 用户地址
     * @param token 代币地址
     * @param long 是否做多
     * @return 用户仓位键
     */
    function _getUserPositionKey(
        address user,
        address token,
        bool long
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, token, long));
    }
    
    /**
     * @dev 批量更新多个代币的资金费率
     * @param tokens 代币地址数组
     */
    function batchUpdateFundingRates(address[] calldata tokens) external {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (configs[tokens[i]].enabled) {
                updateFundingRate(tokens[i]);
            }
        }
    }
    
    /**
     * @dev 紧急暂停代币（仅所有者）
     * @param token 代币地址
     */
    function emergencyPause(address token) external onlyOwner {
        configs[token].enabled = false;
    }
    
    /**
     * @dev 恢复代币（仅所有者）
     * @param token 代币地址
     */
    function emergencyUnpause(address token) external onlyOwner {
        configs[token].enabled = true;
    }
}