pragma solidity ^0.8.0;

/**
 * @title 价格预言机接口
 */
interface IPriceOracle {
    /**
     * @notice 获取资产价格
     * @param cToken cToken 地址
     * @return 价格（以 USD 计价，18 位精度）
     */
    function getUnderlyingPrice(address cToken) external view returns (uint);
}