pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IPriceOracle.sol";

/**
 * @title 简单价格预言机
 * @notice 用于测试的简单价格预言机实现
 */
contract PriceOracle is IPriceOracle, Ownable {
    // 存储各个资产的价格
    mapping(address => uint) public prices;
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @notice 设置资产价格（仅限所有者）
     * @param cToken cToken地址
     * @param price 价格
     */
    function setPrice(address cToken, uint price) external onlyOwner {
        prices[cToken] = price;
    }
    
    /**
     * @notice 获取资产价格
     * @param cToken cToken地址
     * @return 价格
     */
    function getUnderlyingPrice(address cToken) external view override returns (uint) {
        return prices[cToken];
    }
}
