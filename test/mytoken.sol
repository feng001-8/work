pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; // 引入Ownable以使用自定义错误
import "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken public myToken;
    address public owner;
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    uint256 public initialSupply = 1000; // 初始供应量（未含小数位）
    string public name = "MyToken";
    string public symbol = "MTK";
    uint256 public ownerPrivateKey = 0x1; // 用于签名的私钥

    function setUp() public {
        // 从私钥派生所有者地址
        owner = vm.addr(ownerPrivateKey);
        
        // 部署合约，指定所有者为owner
        vm.prank(owner);
        myToken = new MyToken(name, symbol, initialSupply);
    }

    // 测试构造函数初始化
    function testConstructor() public {
        assertEq(myToken.name(), name);
        assertEq(myToken.symbol(), symbol);
        
        uint256 expectedSupply = initialSupply * 10 ** myToken.decimals();
        assertEq(myToken.totalSupply(), expectedSupply);
        assertEq(myToken.balanceOf(owner), expectedSupply);
        assertEq(myToken.owner(), owner);
    }

    // 测试mint函数（正常情况）
    function testMint() public {
        uint256 mintAmount = 500;
        uint256 mintAmountWithDecimals = mintAmount * 10 ** myToken.decimals();
        
        vm.prank(owner);
        myToken.mint(user1, mintAmount);
        
        assertEq(myToken.balanceOf(user1), mintAmountWithDecimals);
        uint256 expectedTotalSupply = (initialSupply + mintAmount) * 10 ** myToken.decimals();
        assertEq(myToken.totalSupply(), expectedTotalSupply);
    }

    // 修复：使用自定义错误匹配
    function testMintRevertWhenNotOwner() public {
        vm.prank(user1);
        // 匹配Ownable的自定义错误
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        myToken.mint(user2, 100);
    }

    // 测试mint函数：铸造到零地址失败
    function testMintRevertWhenToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("mint to zero address");
        myToken.mint(address(0), 100);
    }

    // 测试mint函数：铸造数量为零失败
    function testMintRevertWhenAmountZero() public {
        vm.prank(owner);
        vm.expectRevert("mint amount not zero");
        myToken.mint(user1, 0);
    }

    // 测试burn函数（正常情况）
    function testBurn() public {
        uint256 burnAmount = 200;
        uint256 burnAmountWithDecimals = burnAmount * 10 ** myToken.decimals();
        
        vm.prank(owner);
        myToken.burn(burnAmount);
        
        uint256 expectedBalance = (initialSupply - burnAmount) * 10 ** myToken.decimals();
        assertEq(myToken.balanceOf(owner), expectedBalance);
        assertEq(myToken.totalSupply(), expectedBalance);
    }

    // 测试burn函数：销毁数量为零失败
    function testBurnRevertWhenAmountZero() public {
        vm.prank(owner);
        vm.expectRevert("Burn amount must be positive");
        myToken.burn(0);
    }

    // 测试burn函数：余额不足失败
    function testBurnRevertWhenInsufficientBalance() public {
        uint256 burnAmount = initialSupply + 100;
        
        vm.prank(owner);
        vm.expectRevert("Insufficient balance");
        myToken.burn(burnAmount);
    }

    // 修复：使用正确私钥签名的Permit测试
    function testPermit() public {
        uint256 decimals = myToken.decimals();
        uint256 value = 100 * 10 ** decimals;
        uint256 nonce = myToken.nonces(owner);
        uint256 deadline = block.timestamp + 1 days;

        // 使用正确的私钥生成签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            ownerPrivateKey,
            _getPermitDigest(
                address(myToken),
                owner,
                user1,
                value,
                nonce,
                deadline
            )
        );

        // 执行permit授权
        myToken.permit(owner, user1, value, deadline, v, r, s);
        
        // 验证结果
        assertEq(myToken.allowance(owner, user1), value);
        assertEq(myToken.nonces(owner), nonce + 1);
    }

    // 辅助函数：生成正确的EIP-712签名摘要
    function _getPermitDigest(
        address token,
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                myToken.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner,
                        spender,
                        value,
                        nonce,
                        deadline
                    )
                )
            )
        );
    }
}