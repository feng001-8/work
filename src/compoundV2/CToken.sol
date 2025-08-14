pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IInterestRateModel.sol";

interface IComptroller {
    function borrowAllowed(address cToken, address borrower, uint borrowAmount) external returns (uint);
    function checkMembership(address account, address cToken) external view returns (bool);
}

/**
 * @title CToken
 * @notice Compound Token，代表用户在协议中的存款
 */
contract CToken is ERC20, ReentrancyGuard, Ownable {
    using SafeMath for uint;
    
    // 基本信息
    IERC20 public immutable underlying;           // 底层资产
    IComptroller public immutable comptroller;    // 风险控制器
    IInterestRateModel public interestRateModel;  // 利率模型
    
    // 市场状态
    uint public totalBorrows;                     // 总借贷量
    uint public totalReserves;                    // 总储备金
    uint public reserveFactorMantissa = 0.1e18;   // 储备金比例（10%）
    uint public initialExchangeRateMantissa = 1e18; // 初始兑换率
    
    // 利息累积
    uint public accrualBlockNumber;               // 上次累积利息的区块
    uint public borrowIndex = 1e18;               // 借贷指数
    
    // 用户借贷信息
    struct BorrowSnapshot {
        uint principal;    // 本金
        uint interestIndex; // 利息指数
    }
    mapping(address => BorrowSnapshot) public accountBorrows;
    
    // 事件
    event Mint(address minter, uint mintAmount, uint mintTokens);
    event Redeem(address redeemer, uint redeemAmount, uint redeemTokens);
    event Borrow(address borrower, uint borrowAmount, uint accountBorrows, uint totalBorrows);
    event RepayBorrow(address payer, address borrower, uint repayAmount, uint accountBorrows, uint totalBorrows);
    event LiquidateBorrow(address liquidator, address borrower, uint repayAmount, address cTokenCollateral, uint seizeTokens);
    event AccrueInterest(uint cashPrior, uint interestAccumulated, uint borrowIndex, uint totalBorrows);
    


    constructor(
        address _underlying,
        address _comptroller,
        address _interestRateModel,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        underlying = IERC20(_underlying);
        comptroller = IComptroller(_comptroller);
        interestRateModel = IInterestRateModel(_interestRateModel);
        accrualBlockNumber = block.number;
    }


    /**
     * @notice 累积利息
     */
    function accrueInterest() public {
        uint currentBlockNumber = block.number;
        uint accrualBlockNumberPrior = accrualBlockNumber;
        
        // 如果已经是最新区块，直接返回
        if (accrualBlockNumberPrior == currentBlockNumber) {
            return;
        }
        
        // 获取市场状态
        uint cashPrior = getCash();
        uint borrowsPrior = totalBorrows;
        uint reservesPrior = totalReserves;
        uint borrowIndexPrior = borrowIndex;
        
        // 计算借贷利率
        uint borrowRateMantissa = interestRateModel.getBorrowRate(cashPrior, borrowsPrior, reservesPrior);
        require(borrowRateMantissa <= 0.0005e18, "Borrow rate too high");
        
        // 计算利息
        uint blockDelta = currentBlockNumber.sub(accrualBlockNumberPrior);
        uint simpleInterestFactor = borrowRateMantissa.mul(blockDelta);
        uint interestAccumulated = simpleInterestFactor.mul(borrowsPrior).div(1e18);
        uint totalBorrowsNew = interestAccumulated.add(borrowsPrior);
        uint totalReservesNew = reserveFactorMantissa.mul(interestAccumulated).div(1e18).add(reservesPrior);
        uint borrowIndexNew = simpleInterestFactor.mul(borrowIndexPrior).div(1e18).add(borrowIndexPrior);
        
        // 更新状态
        accrualBlockNumber = currentBlockNumber;
        borrowIndex = borrowIndexNew;
        totalBorrows = totalBorrowsNew;
        totalReserves = totalReservesNew;
        
        emit AccrueInterest(cashPrior, interestAccumulated, borrowIndexNew, totalBorrowsNew);
    }
    
    /**
     * @notice 获取现金余额
     */
    function getCash() public view returns (uint) {
        return underlying.balanceOf(address(this));
    }
    
    /**
     * @notice 获取兑换率
     */
    function exchangeRateStored() public view returns (uint) {
        if (totalSupply() == 0) {
            return initialExchangeRateMantissa;
        } else {
            uint totalCash = getCash();
            uint cashPlusBorrowsMinusReserves = totalCash.add(totalBorrows).sub(totalReserves);
            uint exchangeRate = cashPlusBorrowsMinusReserves.mul(1e18).div(totalSupply());
            return exchangeRate;
        }
    }
    
    /**
      * @notice 获取用户借贷余额
      */
     function borrowBalanceStored(address account) public view returns (uint) {
         BorrowSnapshot storage borrowSnapshot = accountBorrows[account];
         if (borrowSnapshot.principal == 0) {
             return 0;
         }
         
         uint principalTimesIndex = borrowSnapshot.principal.mul(borrowIndex);
         uint result = principalTimesIndex.div(borrowSnapshot.interestIndex);
         return result;
     }
     
     /**
      * @notice 存款功能
      * @param mintAmount 存款金额
      */
     function mint(uint mintAmount) external nonReentrant {
         accrueInterest();
         
         uint exchangeRate = exchangeRateStored();
         uint mintTokens = mintAmount.mul(1e18).div(exchangeRate);
         
         require(underlying.transferFrom(msg.sender, address(this), mintAmount), "Transfer failed");
         
         _mint(msg.sender, mintTokens);
         
         emit Mint(msg.sender, mintAmount, mintTokens);
     }
     
     /**
      * @notice 取款功能
      * @param redeemTokens 要赎回的 cToken 数量
      */
     function redeem(uint redeemTokens) external nonReentrant {
         accrueInterest();
         
         uint exchangeRate = exchangeRateStored();
         uint redeemAmount = redeemTokens.mul(exchangeRate).div(1e18);
         
         require(balanceOf(msg.sender) >= redeemTokens, "Insufficient balance");
         require(getCash() >= redeemAmount, "Insufficient cash");
         
         _burn(msg.sender, redeemTokens);
         require(underlying.transfer(msg.sender, redeemAmount), "Transfer failed");
         
         emit Redeem(msg.sender, redeemAmount, redeemTokens);
     }
     
     /**
      * @notice 借贷功能
      * @param borrowAmount 借贷金额
      */
     function borrow(uint borrowAmount) external nonReentrant {
         accrueInterest();
         
         // 检查是否允许借贷
         uint allowed = comptroller.borrowAllowed(address(this), msg.sender, borrowAmount);
         require(allowed == 0, "Borrow not allowed");
         
         require(getCash() >= borrowAmount, "Insufficient cash");
         
         // 更新借贷信息
         BorrowSnapshot storage borrowSnapshot = accountBorrows[msg.sender];
         uint accountBorrowsPrev = borrowBalanceStored(msg.sender);
         uint accountBorrowsNew = accountBorrowsPrev.add(borrowAmount);
         uint totalBorrowsNew = totalBorrows.add(borrowAmount);
         
         borrowSnapshot.principal = accountBorrowsNew;
         borrowSnapshot.interestIndex = borrowIndex;
         totalBorrows = totalBorrowsNew;
         
         require(underlying.transfer(msg.sender, borrowAmount), "Transfer failed");
         
         emit Borrow(msg.sender, borrowAmount, accountBorrowsNew, totalBorrowsNew);
     }
     
     /**
      * @notice 还款功能
      * @param repayAmount 还款金额
      */
     function repayBorrow(uint repayAmount) external nonReentrant {
         accrueInterest();
         
         BorrowSnapshot storage borrowSnapshot = accountBorrows[msg.sender];
         uint accountBorrowsPrev = borrowBalanceStored(msg.sender);
         
         uint repayAmountFinal = repayAmount;
         if (repayAmount > accountBorrowsPrev) {
             repayAmountFinal = accountBorrowsPrev;
         }
         
         require(underlying.transferFrom(msg.sender, address(this), repayAmountFinal), "Transfer failed");
         
         uint accountBorrowsNew = accountBorrowsPrev.sub(repayAmountFinal);
         uint totalBorrowsNew = totalBorrows.sub(repayAmountFinal);
         
         borrowSnapshot.principal = accountBorrowsNew;
         borrowSnapshot.interestIndex = borrowIndex;
         totalBorrows = totalBorrowsNew;
         
         emit RepayBorrow(msg.sender, msg.sender, repayAmountFinal, accountBorrowsNew, totalBorrowsNew);
     }
}
