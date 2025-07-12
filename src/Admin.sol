
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/IBank.sol";
// 编写一个 Admin 合约， Admin 合约有自己的 Owner ，同时有一个取款函数 adminWithdraw(IBank bank) ,
// adminWithdraw 中会调用 IBank 接口的 withdraw 方法从而把 bank 合约内的资金转移到 Admin 合约地址。
contract Admin {
    // 管理员地址
    address public owner;

    // 构造函数，设置管理员地址为部署者地址
    constructor() {
        owner = msg.sender;
    }

    // 添加接收 ETH 的能力
    receive() external payable {}

    // 取款函数，调用 Bank 合约的 withdraw 方法
    function adminWithdraw(IBank bigBank) public { // 思考为什么使用IBank接口类型？
        require(msg.sender == owner, "Only owner can withdraw");
        bigBank.withdraw();
    }
}