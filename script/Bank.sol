// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/bank.sol";

contract DeployBank is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        Bank bank = new Bank();
        
        console.log("Bank deployed to:", address(bank));
        
        vm.stopBroadcast();
    }
}