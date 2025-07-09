// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/counter.sol";

contract CounterTest is Test{

    Counter public counter;

    function setUp() public{
        counter = new Counter();
               console.log("Contract deployed at address:", address(counter));
    }

    // 验证初始状态
    function test_InitialState() public view {
        assertEq(counter.get(),0);
        console.log("Initial value test passed: counter =", counter.get());
    } 


    // 验证基本功能
    function test_chect_add()public{
        counter.add(5);
        assertEq(counter.get(), 5);
      console.log("Add function test passed: counter =", counter.get());
    }

    // 额外的测试用例
    function test_MultipleAdd() public {
        counter.add(10);
        counter.add(20);
        assertEq(counter.get(), 30);
        console.log("Multiple add test passed: counter =", counter.get());
    }

    
}

/*
# 编译项目
forge build

# 只运行 counters.sol 中的测试
forge test --match-contract CounterTest

# 运行 counters.sol 测试并显示详细输出
forge test --match-contract CounterTest -vvv

# 运行特定的测试函数
forge test --match-test test_check_add
forge test --match-test test_InitialState
forge test --match-test test_MultipleAdd

# 生成 Gas 报告（只针对 CounterTest）
forge test --match-contract CounterTest --gas-report
*/