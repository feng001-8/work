// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MyToken.sol"; // 引入你的 MyToken 合约

contract DeployMyToken is Script {
    // 配置部署参数（可根据需求修改）
    string public constant TOKEN_NAME = "MyToken";       // 代币名称
    string public constant TOKEN_SYMBOL = "MTK";         // 代币符号
    uint256 public constant INITIAL_SUPPLY = 1000000;    // 初始发行量（未含小数位，100万）

    function run() external {
        // 1. 获取部署者私钥（从环境变量读取，安全起见）
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 2. 以部署者身份执行后续操作
        vm.startBroadcast(deployerPrivateKey);
        
        // 3. 部署 MyToken 合约，传入构造函数参数
        MyToken myToken = new MyToken(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            INITIAL_SUPPLY
        );
        
        // 4. 结束广播
        vm.stopBroadcast();
        
        // 5. 输出部署信息
        console.log("MyToken deployed to:");
        console.logAddress(address(myToken));
        console.log("Deployment completed!");
    }
}