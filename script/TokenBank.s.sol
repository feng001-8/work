// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/TokenBank.sol";
import "../src/myToken.sol";

contract DeployTokenBank is Script {
    function run() external {
        vm.startBroadcast();
        
        // 然后部署TokenBank合约
        // Permit2 合约地址 (Sepolia)
        address permit2Address = 0x31c2F6fcFf4F8759b3Bd5Bf0e1084A055615c768;
        
        TokenBank tokenBank = new TokenBank(address(0x9B10283D311A758434212d8Cad690B3e8f4709Cd), permit2Address);
        console.log("TokenBank deployed to:", address(tokenBank));
        
        vm.stopBroadcast();
    }
}