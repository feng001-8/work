// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/TokenBank.sol";

contract DeployTokenBankWithExistingToken is Script {
    function run() external {
        vm.startBroadcast();
        
        // 使用已部署的ERC20代币地址
        address tokenAddress = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
        console.log("Using existing ERC20 Token at:", tokenAddress);
        
        // 部署TokenBank合约
        TokenBank tokenBank = new TokenBank(tokenAddress);
        console.log("TokenBank deployed to:", address(tokenBank));
        
        vm.stopBroadcast();
    }
}
