// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/counter.sol";

contract CounterScript is Script {
    function setUp() public {}

    function run() public {
        // 开始广播交易
        vm.startBroadcast();
        
        // 部署 Counter 合约
        Counter counter = new Counter();
        
        console.log("Counter deployed to:", address(counter));
        console.log("Initial counter value:", counter.get());
        
        // 测试合约功能
        counter.add(42);
        console.log("After adding 42:", counter.get());
        
        vm.stopBroadcast();
    }
}