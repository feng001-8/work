// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
// 导入你自己的 ERC20 合约
import "../src/ERC20.sol";  

contract DeployBaseERC20 is Script {
    function run() external {
        vm.startBroadcast();
        // 2. 部署合约：直接 new 合约，构造函数无参数时可这样写
        BaseERC20 token = new BaseERC20();  

        // 3. 打印部署后的合约地址（方便查看）
        console.log("BaseERC20 deployed to:", address(token));

        vm.stopBroadcast();
    }
}