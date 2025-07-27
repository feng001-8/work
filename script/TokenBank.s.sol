// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/TokenBank.sol";
import "../src/myToken.sol";

contract DeployTokenBank is Script {
    function run() external {
        vm.startBroadcast();
        
        // 然后部署TokenBank合约
        TokenBank tokenBank = new TokenBank(address(0x9B10283D311A758434212d8Cad690B3e8f4709Cd));
        console.log("TokenBank deployed to:", address(tokenBank));
        
        vm.stopBroadcast();
    }
}