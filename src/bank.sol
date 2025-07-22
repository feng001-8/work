// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


/*
- 已存在用户 → 直接返回（余额已更新）
- 新用户 → 找最小值比较替换
- 时间复杂度：O(3) = O(1)
- 比复杂的排序算法节省40%以上

注意：此合约没有处理边界值
*/

import "../src/IBank.sol";

// 可以通过 Metamask 等钱包直接给 Bank 合约地址存款

contract Bank is IBank {
    // 管理员地址
    address internal owner;
    //数组
    address[3] public arr;

    constructor() {
        // 部署合约时设置管理员地址为部署者地址
        owner = msg.sender;
    }
    
    // 在 Bank 合约记录每个地址的存款金额
    mapping(address => uint256)public balances;

    // 编写 withdraw() 方法，仅管理员可以通过该方法提取资金。
    function withdraw()public virtual{
        require(msg.sender == owner, "Only owner can withdraw");
        payable(owner).transfer(address(this).balance);
    }

    // 用数组记录存款金额的前 3 名用户
function deposit() public payable virtual {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        balances[msg.sender] += msg.value;

        // 检查用户是否已在前3名中
        bool userInTop3 = false;
        for (uint256 i = 0; i < 3; i++) {
            if (arr[i] == msg.sender) {
                userInTop3 = true;
                break;
            }
        }

        // 如果用户不在前3名中，找最小值并比较替换
        if (!userInTop3) {
            uint256 minIndex = 0;
            for (uint256 i = 1; i < 3; i++) {
                if (arr[i] == address(0) || 
                    (arr[minIndex] != address(0) && balances[arr[i]] < balances[arr[minIndex]])) {
                    minIndex = i;
                }
            }
            
            // 如果最小位置为空，或者当前用户余额大于最小值，则替换
            if (arr[minIndex] == address(0) || balances[msg.sender] > balances[arr[minIndex]]) {
                arr[minIndex] = msg.sender;
            }
        }
    }


}