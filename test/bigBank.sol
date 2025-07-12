pragma solidity ^0.8.0;



import "../src/Bigbank.sol";

import "../src/Admin.sol"; 
import "forge-std/Test.sol";
import "forge-std/console.sol";



contract TestBigBank {

    BigBank public bigBank;
    Admin public admin;

    constructor() {
        bigBank = new BigBank();
        admin = new Admin();
        
        // 转移 BigBank 的所有权给 Admin 合约
        bigBank.transferOwnership(address(admin));
    }

    function testDeposit() public payable {
        bigBank.deposit{value: 0.0001 ether}();
    }

    function testAdminWithdraw() public {
        admin.adminWithdraw(bigBank);
    }
}



