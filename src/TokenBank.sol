// 编写一个 TokenBank 合约，可以将自己的 Token 存入到 TokenBank， 和从 TokenBank 取出。

// TokenBank 有两个方法：

// deposit() : 需要记录每个地址的存入数量；
// withdraw（）: 用户可以提取自己的之前存入的 token。



// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./myToken.sol";

contract TokenBank {
    // 记录每个地址在银行中的余额
    mapping(address => uint256) public balances;
    
    // ERC20代币合约地址
    MyToken public token;
    
    // 事件
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    
    // 构造函数，设置要管理的ERC20代币
    constructor(address _tokenAddress) {
        token = MyToken(_tokenAddress);
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

    // 离线签名授权存款函数：通过 permit 直接授权并存款
    function permitDeposit(
        address owner,        // 代币所有者（存款人）
        uint256 value,        // 存款金额
        uint256 deadline,     // 签名有效期截止时间
        uint8 v,              // 签名参数 v
        bytes32 r,            // 签名参数 r
        bytes32 s             // 签名参数 s
    ) external {
        require(value > 0, "Amount must be greater than 0");
        require(block.timestamp <= deadline, "Permit expired");
        require(token.balanceOf(owner) >= value, "Owner has insufficient tokens");
        
        // 1. 执行 permit 授权：通过离线签名授权 TokenBank 转移 owner 的代币
        token.permit(
            owner,          // 代币所有者
            address(this),  // 被授权方（TokenBank 合约）
            value,          // 授权金额
            deadline,       // 签名有效期
            v, r, s         // 签名参数
        );
        
        // 2. 从 owner 转移授权的代币到合约
        bool success = token.transferFrom(owner, address(this), value);
        require(success, "Transfer failed after permit");
        
        // 3. 更新 owner 在银行的存款余额
        balances[owner] += value;
        emit Deposit(owner, value);
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