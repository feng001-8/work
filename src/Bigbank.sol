// BigBank 和 Admin 合约 部署后，把 BigBank 的管理员转移给 Admin 合约地址，模拟几个用户的存款，然后

// Admin 合约的Owner地址调用 adminWithdraw(IBank bank) 把 BigBank 的资金转移到 Admin 地址。




// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Bank.sol";
// 在 该挑战 的 Bank 合约基础之上，编写 IBank 接口及BigBank 合约，使其满足 Bank 实现 IBank， BigBank 继承自 Bank ， 同时 BigBank 有附加要求：



contract BigBank is Bank{

// 要求存款金额 >0.001 ether（用modifier权限控制）
    modifier validDeposit() {
        require(msg.value >= 0.001 ether, "Deposit amount must be at least 0.001 ether");
        _;
    }
      
    // 重写
    function deposit() public payable override validDeposit{
        super.deposit();
    }

    // 转移管理者
    function transferOwnership(address newOwner) public virtual {
        require(msg.sender == owner, "Only current owner can transfer ownership");
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
        emit OwnershipTransferred(msg.sender, newOwner);
    }
    
    // 添加事件定义
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}



