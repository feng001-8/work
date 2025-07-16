pragma solidity ^0.8.0;

import "./ERC20.sol";

// 编写一个 TokenBank 合约，可以将自己的 Token 存入到 TokenBank， 和从 TokenBank 取出。

// TokenBank 有两个方法：

// deposit() : 需要记录每个地址的存入数量；
// withdraw（）: 用户可以提取自己的之前存入的 token。

contract TokenBank {
    // 代币合约
    BaseERC20 public token;// 理解什么是代币 什么是银行？
    
    // 记录每个地址的存入数量
    mapping(address => uint256) public deposits;//本质来说就是一个交易凭证
    
    // 总存款量
    uint256 public totalDeposits;
    
    // 事件
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    
    // 构造函数，指定要管理的代币合约地址
    constructor(address _token) {
        require(_token != address(0), "Invalid token address");
        token = BaseERC20(_token);
    }
    
    // 存款函数
    function deposit(uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");
        
        // 检查用户是否有足够的代币
        require(token.balanceOf(msg.sender) >= amount, "Insufficient token balance");  // 理解为什么存款函数为什么要检查用户是否有足够的代币
        
        // 检查用户是否已授权足够的代币给银行合约
        require(token.allowance(msg.sender, address(this)) >= amount, "Insufficient allowance");// 为什么要先授？今天授权了一笔交易 明天还能使用吗？ 他的额度是怎么做的 如何保证安全性
        
        // 从用户账户转移代币到银行合约
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");
        
        // 记录用户存款
        deposits[msg.sender] += amount;
        totalDeposits += amount;
        
        emit Deposit(msg.sender, amount);
    }
    
    // 取款函数
    function withdraw(uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");
        require(deposits[msg.sender] >= amount, "Insufficient deposit balance");
        
        // 更新用户存款记录cc
        deposits[msg.sender] -= amount;
        totalDeposits -= amount;
        
        // 从银行合约转移代币回给用户
        bool success = token.transfer(msg.sender, amount);
        require(success, "Transfer failed");
        
        emit Withdraw(msg.sender, amount);
    }
    
    // 查询用户存款余额
    function getDepositBalance(address user) public view returns (uint256) {
        return deposits[user];
    }
    
    // 查询银行合约持有的代币总量
    function getBankBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

}
