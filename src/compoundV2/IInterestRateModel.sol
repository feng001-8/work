pragma solidity ^0.8.0;

/**
 * @title 利率模型接口
 */
interface IInterestRateModel {
    /**
     * @notice 计算每区块的借贷利率
     * @param cash 市场现金
     * @param borrows 总借贷量
     * @param reserves 储备金
     * @return 每区块借贷利率
     */
    function getBorrowRate(uint cash, uint borrows, uint reserves) external view returns (uint);
    
    /**
     * @notice 计算每区块的存款利率
     * @param cash 市场现金
     * @param borrows 总借贷量
     * @param reserves 储备金
     * @param reserveFactorMantissa 储备金比例
     * @return 每区块存款利率
     */
    function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) external view returns (uint);
}
