// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/HPAI.sol";

contract HPAISecurityTest is Test {
    HPAI public hpai;
    address payable public constant HPAI_ADDRESS = payable(0x8B8796b825c3714AB5C498e9B5e2Bc8dd02a156d);
    address public attacker;
    address public victim;
    address public newTaxWallet;
    
    function setUp() public {
        // Fork mainnet - use RPC URL from environment variables
        string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
        vm.createFork(rpcUrl);
        
        // Get deployed HPAI contract
        hpai = HPAI(HPAI_ADDRESS);
        
        // Setup test addresses
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
        newTaxWallet = makeAddr("newTaxWallet");
        
        // Give test addresses some ETH
        vm.deal(attacker, 10 ether);
        vm.deal(victim, 10 ether);
    }
    
    // Test 1: transferFrom authorization bypass vulnerability
    function testTransferFromAuthorizationBypass() public {
        console.log("=== Testing transferFrom Authorization Bypass ===");
        
        // Get some tokens for victim
        address tokenHolder = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045; // Vitalik's address
        vm.startPrank(tokenHolder);
        
        uint256 transferAmount = 1000 * 10**9; // 1000 tokens
        if (hpai.balanceOf(tokenHolder) >= transferAmount) {
            hpai.transfer(victim, transferAmount);
        }
        vm.stopPrank();
        
        uint256 victimBalance = hpai.balanceOf(victim);
        console.log("Victim balance:", victimBalance);
        
        if (victimBalance > 0) {
            // Attacker tries to transfer victim's tokens without authorization
            vm.startPrank(attacker);
            
            uint256 attackAmount = victimBalance / 2;
            
            try hpai.transferFrom(victim, attacker, attackAmount) {
                console.log("WARNING: Authorization bypass successful! Attacker transferred tokens");
                console.log("Attacker gained tokens:", hpai.balanceOf(attacker));
            } catch {
                console.log("Authorization check working properly");
            }
            
            vm.stopPrank();
        }
    }
    
    // Test 2: setTaxWallet access control vulnerability
    function testSetTaxWalletAccessControl() public {
        console.log("=== Testing setTaxWallet Access Control ===");
        
        // Attacker tries to modify tax wallet
        vm.startPrank(attacker);
        
        try hpai.setTaxWallet(payable(newTaxWallet)) {
            console.log("WARNING: Attacker successfully modified tax wallet!");
            console.log("New tax wallet address:", newTaxWallet);
        } catch {
            console.log("setTaxWallet access control working properly");
        }
        
        vm.stopPrank();
    }
    
    // Test 3: Reentrancy attack test
    function testReentrancyAttack() public {
        console.log("=== Testing Reentrancy Attack ===");
        
        // Create malicious contract for reentrancy attack test
        MaliciousContract malicious = new MaliciousContract(HPAI_ADDRESS);
        
        vm.deal(address(malicious), 1 ether);
        
        vm.startPrank(address(malicious));
        
        try malicious.attack() {
            console.log("WARNING: Reentrancy attack might be successful!");
        } catch {
            console.log("Reentrancy attack blocked");
        }
        
        vm.stopPrank();
    }
    
    // Test 4: Check basic security features
    function testBasicSecurityFeatures() public {
        console.log("=== Checking Basic Security Features ===");
        
        // Check total supply
        uint256 totalSupply = hpai.totalSupply();
        console.log("Total supply:", totalSupply);
        
        // Check owner
        address owner = hpai.owner();
        console.log("Contract owner:", owner);
        
        // Check if contract can receive ETH
        vm.deal(address(this), 1 ether);
        (bool success,) = address(hpai).call{value: 0.1 ether}("");
        if (success) {
            console.log("Contract can receive ETH");
        } else {
            console.log("Contract cannot receive ETH");
        }
    }
    
    // Test 5: Check tax mechanism
    function testTaxMechanism() public {
        console.log("=== Testing Tax Mechanism ===");
        
        // Need to simulate Uniswap transactions to test tax
        // Due to complexity, only basic checks here
        
        address tokenHolder = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        
        vm.startPrank(tokenHolder);
        
        uint256 beforeBalance = hpai.balanceOf(tokenHolder);
        uint256 transferAmount = 1000 * 10**9;
        
        if (beforeBalance >= transferAmount) {
            hpai.transfer(victim, transferAmount);
            uint256 afterBalance = hpai.balanceOf(tokenHolder);
            uint256 receivedAmount = hpai.balanceOf(victim);
            
            console.log("Balance before transfer:", beforeBalance);
            console.log("Balance after transfer:", afterBalance);
            console.log("Amount received:", receivedAmount);
            console.log("Actual deduction:", beforeBalance - afterBalance);
        }
        
        vm.stopPrank();
    }
}

// Malicious contract for testing reentrancy attacks
contract MaliciousContract {
    HPAI public hpai;
    bool public attacking = false;
    
    constructor(address payable _hpai) {
        hpai = HPAI(_hpai);
    }
    
    function attack() external {
        attacking = true;
        // Try reentrancy attack
        hpai.transfer(address(this), 1);
    }
    
    receive() external payable {
        if (attacking && address(hpai).balance > 0) {
            // Try reentrancy
            attacking = false;
            hpai.transfer(msg.sender, 1);
        }
    }
}