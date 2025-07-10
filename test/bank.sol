// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;



import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/bank.sol";


contract TestBank is Test{
    // 测试账户
    Bank public bankContract;
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;


    function setUp() public{
        owner = address(this);
         user1 = address(0x1);
         user2 = address(0x2);
         user3 = address(0x3);
         user4 = address(0x4);

         vm.deal(user1, 100 ether);
         vm.deal(user2, 100 ether); 
         vm.deal(user3, 100 ether);
         vm.deal(user4, 100 ether);

         bankContract = new Bank();
        console.log("owner address is ",owner);
    }

    // 测试存款功能
    function testDeposit()public {
        uint256 depositAmount = 10 ether;
        vm.prank(user1);
        bankContract.deposit{value: depositAmount}();

        //验证余额
        assertEq(bankContract.balances(user1), depositAmount, "User1 should have 10 ether balance");
        assertEq(address(bankContract).balance,depositAmount, "Bank contract should have 10 ether balance"); // balance函数是地址
    }
    // 测试多次存款功能
    function testDepositTWO() public {
        uint256 depositAmount = 1 ether;
        vm.prank(user1);
        bankContract.deposit{value: depositAmount}();
        vm.prank(user2);
        bankContract.deposit{value: depositAmount}();
        //验证余额
        assertEq(bankContract.balances(user1), depositAmount, "User1 should have 1 ether balance");
        assertEq(bankContract.balances(user2), depositAmount, "User1 should have 1 ether balance");
        assertEq(address(bankContract).balance,2 ether, "Bank contract should have 2 ether balance"); // balance函数是地址

    }

    function testTopThreeUsers() public {
        // user1存款5 ether
        vm.prank(user1);
        bankContract.deposit{value: 5 ether}();
        
        // user2存款3 ether
        vm.prank(user2);
        bankContract.deposit{value: 3 ether}();
        
        // user3存款7 ether
        vm.prank(user3);
        bankContract.deposit{value: 7 ether}();
        
        // user4存款10 ether
        vm.prank(user4);
        bankContract.deposit{value: 10 ether}();
        


        // 验证前3名用户
        console.log(bankContract.arr(0));
        console.log(bankContract.arr(1));
        console.log(bankContract.arr(2));
    }

    
}
