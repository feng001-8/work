pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IInterestRateModel.sol";

/**
 * @title 简单线性利率模型
 * @notice 实现简单的线性利率计算
 */
contract SimpleInterestRateModel is IInterestRateModel {
    using SafeMath for uint;
    
    // 利率参数（年化利率转换为每区块利率）
    uint public constant BASE_RATE_PER_YEAR = 0.02e18;  // 2% 基础年利率
    uint public constant MULTIPLIER_PER_YEAR = 0.1e18;  // 10% 乘数
    uint public constant BLOCKS_PER_YEAR = 2102400;     // 每年区块数
    
    uint public constant BASE_RATE_PER_BLOCK = BASE_RATE_PER_YEAR / BLOCKS_PER_YEAR;
    uint public constant MULTIPLIER_PER_BLOCK = MULTIPLIER_PER_YEAR / BLOCKS_PER_YEAR;
    
    /**
     * @notice 计算利用率
     * @param cash 现金
     * @param borrows 借贷量
     * @param reserves 储备金
     * @return 利用率（0-1e18）
     */
    function utilizationRate(uint cash, uint borrows, uint reserves) public pure returns (uint) {
        if (borrows == 0) {
            return 0;
        }
        return borrows.mul(1e18).div(cash.add(borrows).sub(reserves));
    }
    
    /**
     * @notice 计算借贷利率
     */
    function getBorrowRate(uint cash, uint borrows, uint reserves) external view override returns (uint) {
        uint ur = utilizationRate(cash, borrows, reserves);
        return ur.mul(MULTIPLIER_PER_BLOCK).div(1e18).add(BASE_RATE_PER_BLOCK);
    }
    
    /**
     * @notice 计算存款利率
     */
    function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) external view override returns (uint) {
        uint oneMinusReserveFactor = uint(1e18).sub(reserveFactorMantissa);
        uint borrowRate = this.getBorrowRate(cash, borrows, reserves);
        uint rateToPool = borrowRate.mul(oneMinusReserveFactor).div(1e18);
        return utilizationRate(cash, borrows, reserves).mul(rateToPool).div(1e18);
    }
}