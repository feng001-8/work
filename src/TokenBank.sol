// 编写一个 TokenBank 合约，可以将自己的 Token 存入到 TokenBank， 和从 TokenBank 取出。

// TokenBank 有两个方法：

// deposit() : 需要记录每个地址的存入数量；
// withdraw（）: 用户可以提取自己的之前存入的 token。



// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./ERC20.sol";

contract TokenBank {
    // 记录每个地址在银行中的余额
    mapping(address => uint256) public balances;
    
    // ERC20代币合约地址
    BaseERC20 public token;
    
    // 事件
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    
    // 构造函数，设置要管理的ERC20代币
    constructor(address _tokenAddress) {
        token = BaseERC20(_tokenAddress);
    }
    
    // 存款函数
    function deposit(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient token balance");
        
        // 从用户账户转移代币到合约
        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        
        // 更新用户在银行的余额
        balances[msg.sender] += _amount;
        
        emit Deposit(msg.sender, _amount);
    }
    
    // 取款函数
    function withdraw(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= _amount, "Insufficient bank balance");
        
        // 更新用户在银行的余额
        balances[msg.sender] -= _amount;
        
        // 从合约转移代币到用户账户
        require(token.transfer(msg.sender, _amount), "Transfer failed");
        
        emit Withdraw(msg.sender, _amount);
    }
    
    // 查询用户在银行的余额
    function getBankBalance(address _user) external view returns (uint256) {
        return balances[_user];
    }
    
    // 查询合约中的总代币余额
    function getTotalDeposits() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}