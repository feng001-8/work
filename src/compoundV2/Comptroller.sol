pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IPriceOracle {
    function getUnderlyingPrice(address cToken) external view returns (uint);
}

interface ICToken {
    function balanceOf(address account) external view returns (uint);
    function borrowBalanceStored(address account) external view returns (uint);
    function exchangeRateStored() external view returns (uint);
    function underlying() external view returns (address);
}

contract Comptroller is Ownable {
    using SafeMath for uint;
    
    // 市场信息结构
    struct Market {
        bool isListed;                    // 是否已上线
        uint collateralFactorMantissa;    // 抵押率（0-0.9e18）
        mapping(address => bool) accountMembership; // 用户是否加入市场
    }

    // 状态变量
    mapping(address => Market) public markets;           // 市场信息
    mapping(address => address[]) public accountAssets;  // 用户参与的市场
    IPriceOracle public oracle;                         // 价格预言机
    uint public closeFactorMantissa = 0.5e18;          // 清算比例（50%）
    uint public liquidationIncentiveMantissa = 1.08e18; // 清算奖励（8%）

    // 事件
    event MarketListed(address cToken);
    event MarketEntered(address cToken, address account);
    event MarketExited(address cToken, address account);

    constructor(address _oracle) Ownable(msg.sender) {
        oracle = IPriceOracle(_oracle);
    }


    // 上架市场
    function supportMarket(address cToken, uint collateralFactorMantissa) external onlyOwner {
        require(!markets[cToken].isListed, "Market already listed");
        require(collateralFactorMantissa <= 0.9e18, "Collateral factor too high");
    
        markets[cToken].isListed = true;
        markets[cToken].collateralFactorMantissa = collateralFactorMantissa;
        emit MarketListed(cToken);
    }

    // 用户进入市场
    function enterMarkets(address[] memory cTokens) external returns(uint256[] memory) {
        uint256[] memory results = new uint256[](cTokens.length);
        for (uint i = 0; i < cTokens.length; i++) {
            address cToken = cTokens[i];
            
            if (!markets[cToken].isListed) {
                results[i] = 1; // 市场未上线
                continue;
            }
            
            // 检查用户是否已加入市场
            if (markets[cToken].accountMembership[msg.sender]) {
                results[i] = 0; // 已经加入
                continue;
            }
           
            // 加入市场
            markets[cToken].accountMembership[msg.sender] = true;
            accountAssets[msg.sender].push(cToken);
            
            emit MarketEntered(cToken, msg.sender);
            results[i] = 0;
        }
        
        return results;
    }

    // 检查用户是否可以借贷
    function borrowAllowed(address cToken, address borrower, uint256 borrowAmount) external view returns(uint8) {
        require(markets[cToken].isListed, "Market not listed");
        require(markets[cToken].accountMembership[borrower], "Borrower not in market");

        // 获取账户流动性
        (, uint liquidity, uint shortfall) = getAccountLiquidityInternal(borrower);
        
        if (shortfall > 0) {
            return 3; // 账户不健康
        }

        // 检查贷款之后是否健康 
        uint256 borrowValue = borrowAmount.mul(oracle.getUnderlyingPrice(cToken)).div(1e18);
        if (borrowValue > liquidity) {
            return 4; // 流动性不足
        }
        return 0;
    } 

  

    // 查用户是否可以被清算
    function liquidateBorrowAllowed(
        address cTokenBorrowed, // 借贷市场
        address cTokenCollateral,// 抵押品市场
        address borrower,// 借贷者
        uint256 repayAmount// 偿还金额
    )  external view returns(uint256){
        // 检查市场是否上线
        if (!markets[cTokenBorrowed].isListed || !markets[cTokenCollateral].isListed) {
            return 1;
        }
        // 检查账户是否不健康
        (, , uint shortfall) = getAccountLiquidityInternal(borrower);
        if (shortfall == 0) {
            return 2; // 账户健康，不能清算
        }

        // TODO 检查清算金额是否合理


        return 0;// 运行清算
    }

    /**
     * @notice 获取用户账户流动性
     * @param account 用户地址
     * @return (错误码, 流动性, 不足额)
     */

    function getAccountLiquidity(address account) external view returns(uint256, uint256, uint256) {
        return getAccountLiquidityInternal(account); 
    }

    // 计算账户流动性
    function getAccountLiquidityInternal(address account) internal view returns(uint256, uint256, uint256) {
        // 遍历用户参与的市场
        address[] memory assets = accountAssets[account];
        uint sumCollateral = 0;
        uint sumBorrowPlusEffects = 0;
        
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            
            // 获取用户余额
            uint256 cTokenBalance = ICToken(asset).balanceOf(account);
            uint256 borrowBalance = ICToken(asset).borrowBalanceStored(account);
            uint256 exchangeRate = ICToken(asset).exchangeRateStored();
            uint256 oraclePrice = oracle.getUnderlyingPrice(asset);
            
            // 计算抵押品价值
            uint256 tokensToDenom = cTokenBalance.mul(exchangeRate).div(1e18);
            uint256 collateralValue = tokensToDenom.mul(oraclePrice).div(1e18);
            uint256 weightedCollateral = collateralValue.mul(markets[asset].collateralFactorMantissa).div(1e18);
            
            sumCollateral = sumCollateral.add(weightedCollateral);
            
            // 计算借贷价值
            uint256 borrowValue = borrowBalance.mul(oraclePrice).div(1e18);
            sumBorrowPlusEffects = sumBorrowPlusEffects.add(borrowValue);
        }
        
        // 计算流动性
        if (sumCollateral > sumBorrowPlusEffects) {
            return (0, sumCollateral.sub(sumBorrowPlusEffects), 0);
        } else {
            return (0, 0, sumBorrowPlusEffects.sub(sumCollateral));
        }
    }


        /**
     * @notice 获取用户参与的市场
     */
    function getAssetsIn(address account) external view returns (address[] memory) {
        return accountAssets[account];
    }

    /**
     * @notice 更新价格预言机
     */
    function setPriceOracle(address newOracle) external onlyOwner {
        oracle = IPriceOracle(newOracle);
    }
}


