// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TokenBank.sol";
import "../src/myToken.sol";

contract TokenBankTest is Test {
    TokenBank public tokenBank;
    MyToken public token;
    
    address public owner;
    address public delegate;
    address public user;
    
    uint256 constant OWNER_PRIVATE_KEY = 0x1;
    uint256 constant DELEGATE_PRIVATE_KEY = 0x2;
    uint256 constant USER_PRIVATE_KEY = 0x3;
    
    uint256 constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 constant TEST_AMOUNT = 1000 * 10**18;
    
    function setUp() public {
        // 从私钥生成地址
        owner = vm.addr(OWNER_PRIVATE_KEY);
        delegate = vm.addr(DELEGATE_PRIVATE_KEY);
        user = vm.addr(USER_PRIVATE_KEY);
        
        // 部署代币合约
        token = new MyToken("Test Token", "TEST", INITIAL_SUPPLY / 10**18);
        
        // 部署 TokenBank 合约
        tokenBank = new TokenBank(address(token));
        
        // 给测试账户分配代币
        token.transfer(owner, TEST_AMOUNT * 10);
        token.transfer(user, TEST_AMOUNT * 5);
        
        // 设置标签便于调试
        vm.label(owner, "Owner");
        vm.label(delegate, "Delegate");
        vm.label(user, "User");
        vm.label(address(token), "MyToken");
        vm.label(address(tokenBank), "TokenBank");
    }
    
    function testBasicDeposit() public {
        vm.startPrank(user);
        
        // 授权 TokenBank 使用代币
        token.approve(address(tokenBank), TEST_AMOUNT);
        
        // 存款
        tokenBank.deposit(TEST_AMOUNT);
        
        // 验证余额
        assertEq(tokenBank.getBankBalance(user), TEST_AMOUNT);
        assertEq(token.balanceOf(address(tokenBank)), TEST_AMOUNT);
        
        vm.stopPrank();
    }
    
    function testBasicWithdraw() public {
        // 先存款
        testBasicDeposit();
        
        vm.startPrank(user);
        
        uint256 withdrawAmount = TEST_AMOUNT / 2;
        
        // 取款
        tokenBank.withdraw(withdrawAmount);
        
        // 验证余额
        assertEq(tokenBank.getBankBalance(user), TEST_AMOUNT - withdrawAmount);
        assertEq(token.balanceOf(address(tokenBank)), TEST_AMOUNT - withdrawAmount);
        
        vm.stopPrank();
    }
    
    function testPermitDeposit() public {
        vm.startPrank(owner);
        
        uint256 deadline = block.timestamp + 1 hours;
        
        // 生成 permit 签名
        bytes32 permitHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            owner,
            address(tokenBank),
            TEST_AMOUNT,
            token.nonces(owner),
            deadline
        ));
        
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            permitHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PRIVATE_KEY, digest);
        
        vm.stopPrank();
        
        // 任何人都可以调用 permitDeposit
        tokenBank.permitDeposit(owner, TEST_AMOUNT, deadline, v, r, s);
        
        // 验证余额
        assertEq(tokenBank.getBankBalance(owner), TEST_AMOUNT);
        assertEq(token.balanceOf(address(tokenBank)), TEST_AMOUNT);
    }
    
    function testDelegateDepositWithPermit() public {
        uint256 deadline = block.timestamp + 1 hours;
        
        // 授权人（owner）生成 permit 签名（离线操作）
        bytes32 permitHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            owner,
            address(tokenBank),
            TEST_AMOUNT,
            token.nonces(owner),
            deadline
        ));
        
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            permitHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PRIVATE_KEY, digest);
        
        // 记录执行前的状态
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 bankBalanceBefore = tokenBank.getBankBalance(owner);
        uint256 contractBalanceBefore = token.balanceOf(address(tokenBank));
        
        console.log("Owner token balance before:", ownerBalanceBefore);
        console.log("Owner bank balance before:", bankBalanceBefore);
        console.log("Contract token balance before:", contractBalanceBefore);
        
        // 委托人（delegate）执行委托存款（支付gas费用）
        vm.prank(delegate);
        tokenBank.delegateDepositWithPermit(owner, delegate, TEST_AMOUNT, deadline, v, r, s);
        
        // 验证存款成功
        assertEq(tokenBank.getBankBalance(owner), TEST_AMOUNT);
        assertEq(token.balanceOf(address(tokenBank)), TEST_AMOUNT);
        assertEq(token.balanceOf(owner), ownerBalanceBefore - TEST_AMOUNT);
        
        console.log("Owner token balance after:", token.balanceOf(owner));
        console.log("Owner bank balance after:", tokenBank.getBankBalance(owner));
        console.log("Contract token balance after:", token.balanceOf(address(tokenBank)));
    }
    
    function testDelegateDepositWithPermitNonceConsumption() public {
        // 这个测试验证委托存款的nonce消耗逻辑
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonceBefore = token.nonces(owner);
        
        // 授权人（owner）生成 permit 签名
        bytes32 permitHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            owner,
            address(tokenBank),
            TEST_AMOUNT,
            nonceBefore,
            deadline
        ));
        
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            permitHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PRIVATE_KEY, digest);
        
        console.log("Nonce before delegateDepositWithPermit:", nonceBefore);
        console.log("Allowance before delegateDepositWithPermit:", token.allowance(owner, address(tokenBank)));
        
        // 委托人执行委托存款
        vm.prank(delegate);
        tokenBank.delegateDepositWithPermit(owner, delegate, TEST_AMOUNT, deadline, v, r, s);
        
        uint256 nonceAfter = token.nonces(owner);
        uint256 allowanceAfter = token.allowance(owner, address(tokenBank));
        
        console.log("Nonce after delegateDepositWithPermit:", nonceAfter);
        console.log("Allowance after delegateDepositWithPermit:", allowanceAfter);
        
        // 验证 nonce 已经被消耗
        assertEq(nonceAfter, nonceBefore + 1);
        
        // 验证存款成功
        assertEq(tokenBank.getBankBalance(owner), TEST_AMOUNT);
        assertEq(token.balanceOf(address(tokenBank)), TEST_AMOUNT);
    }
    
    function testRevertWhenDelegateDepositWithInvalidSignature() public {
        uint256 deadline = block.timestamp + 1 hours;
        
        // 使用错误的私钥生成签名
        bytes32 permitHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            owner,
            address(tokenBank),
            TEST_AMOUNT,
            token.nonces(owner),
            deadline
        ));
        
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            permitHash
        ));
        
        // 使用错误的私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(USER_PRIVATE_KEY, digest);
        
        vm.prank(delegate);
        vm.expectRevert(); // 期望任何revert，因为不同版本的错误消息可能不同
        tokenBank.delegateDepositWithPermit(owner, delegate, TEST_AMOUNT, deadline, v, r, s);
    }
    
    function testRevertWhenWrongDelegateExecutes() public {
        uint256 deadline = block.timestamp + 1 hours;
        
        // 授权人生成 permit 签名
        bytes32 permitHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            owner,
            address(tokenBank),
            TEST_AMOUNT,
            token.nonces(owner),
            deadline
        ));
        
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            permitHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PRIVATE_KEY, digest);
        
        // 错误的委托人尝试执行（user而不是delegate）
        vm.prank(user);
        vm.expectRevert("Only delegate can execute");
        tokenBank.delegateDepositWithPermit(owner, delegate, TEST_AMOUNT, deadline, v, r, s);
    }
}