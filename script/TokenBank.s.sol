// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/TokenBank.sol";
import "../src/ERC20.sol";

contract DeployTokenBank is Script {
    function run() external {
        vm.startBroadcast();
        
        // 首先部署ERC20代币
        BaseERC20 token = new BaseERC20();
        console.log("ERC20 Token deployed to:", address(token));
        
        // 然后部署TokenBank合约
        TokenBank tokenBank = new TokenBank(address(token));
        console.log("TokenBank deployed to:", address(tokenBank));
        
        vm.stopBroadcast();
    }
}