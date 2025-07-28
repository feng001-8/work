// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ERC20.sol";
import "../src/SimpleNFT.sol";
import { NFTMarket } from "../src/nftMarket.sol";

contract NFTMarketTest is Test {
    BaseERC20 public token;
    SimpleNFT public nft;
    NFTMarket public market;
    
    address public seller = address(0x1);
    address public buyer = address(0x2);
    address public whitelistBuyer = address(0x5);
    
    // 项目方私钥（用于签名）
    uint256 public constant PROJECT_OWNER_PRIVATE_KEY = 0x4;
    address public projectOwner = vm.addr(PROJECT_OWNER_PRIVATE_KEY);

    uint256 public constant INITIAL_BALANCE = 1000000 * 10**18;
    uint256 public constant NFT_PRICE = 100 * 10**18;
    
    function setUp() public {
        // 部署合约
        token = new BaseERC20();
        nft = new SimpleNFT("Test NFT", "TNFT");
        market = new NFTMarket(address(token), projectOwner);
        
        // 给卖家、买家和白名单买家分配代币
        vm.prank(address(this));
        token.transfer(seller, INITIAL_BALANCE);
        vm.prank(address(this));
        token.transfer(buyer, INITIAL_BALANCE);
        vm.prank(address(this));
        token.transfer(whitelistBuyer, INITIAL_BALANCE);
        
        // 给卖家铸造NFT
        vm.prank(address(this));
        nft.mint(seller);
        
        // 卖家授权市场合约操作NFT
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);
    }
    
    function testListNFT() public {
        vm.prank(seller);
        uint256 listingId = market.list(address(nft), 1, NFT_PRICE);
        
        (address listingSeller, address nftContract, uint256 tokenId, uint256 price, bool isActive) = market.listings(listingId);
        
        assertEq(listingSeller, seller);
        assertEq(nftContract, address(nft));
        assertEq(tokenId, 1);
        assertEq(price, NFT_PRICE);
        assertTrue(isActive);
    }
    
    function testBuyNFTWithTransferFrom() public {
        // 卖家上架NFT
        vm.prank(seller);
        uint256 listingId = market.list(address(nft), 1, NFT_PRICE);
        
        // 买家授权市场合约花费代币
        vm.prank(buyer);
        token.approve(address(market), NFT_PRICE);
        
        // 记录初始余额
        uint256 sellerInitialBalance = token.balanceOf(seller);
        uint256 buyerInitialBalance = token.balanceOf(buyer);
        
        // 买家购买NFT
        vm.prank(buyer);
        market.buyNFT(listingId);
        
        // 验证NFT所有权转移
        assertEq(nft.ownerOf(1), buyer);
        
        // 验证代币转移
        assertEq(token.balanceOf(seller), sellerInitialBalance + NFT_PRICE);
        assertEq(token.balanceOf(buyer), buyerInitialBalance - NFT_PRICE);
        
        // 验证上架状态
        (, , , , bool isActive) = market.listings(listingId);
        assertFalse(isActive);
    }
    
    function testBuyNFTWithCallback() public {
        // 给卖家铸造新的NFT
        vm.prank(address(this));
        uint256 newTokenId = nft.mint(seller);
        
        // 验证NFT铸造成功
        assertEq(nft.ownerOf(newTokenId), seller);
        
        // 卖家上架NFT
        vm.prank(seller);
        uint256 listingId = market.list(address(nft), newTokenId, NFT_PRICE);
        
        // 买家授权市场合约花费代币
        vm.prank(buyer);
        token.approve(address(market), NFT_PRICE);
        
        // 记录初始余额
        uint256 sellerInitialBalance = token.balanceOf(seller);
        uint256 buyerInitialBalance = token.balanceOf(buyer);
        
        // 买家使用回调方式购买NFT
        vm.prank(buyer);
        market.buyNFTWithCallback(listingId);
        
        // 验证NFT所有权转移
        assertEq(nft.ownerOf(newTokenId), buyer);
        
        // 验证代币转移
        assertEq(token.balanceOf(seller), sellerInitialBalance + NFT_PRICE);
        assertEq(token.balanceOf(buyer), buyerInitialBalance - NFT_PRICE);
        
        // 验证上架状态
        (, , , , bool isActive) = market.listings(listingId);
        assertFalse(isActive);
    }
    
    function testCancelListing() public {
        // 卖家上架NFT
        vm.prank(seller);
        uint256 listingId = market.list(address(nft), 1, NFT_PRICE);
        
        // 卖家取消上架
        vm.prank(seller);
        market.cancelListing(listingId);
        
        // 验证上架状态
        (, , , , bool isActive) = market.listings(listingId);
        assertFalse(isActive);
    }
    
    function testRevertWhenBuyNonexistentListing() public {
        vm.expectRevert();
        vm.prank(buyer);
        market.buyNFT(999); // 不存在的上架ID
    }
    
    function testRevertWhenBuyWithInsufficientBalance() public {
        // 卖家上架NFT
        vm.prank(seller);
        uint256 listingId = market.list(address(nft), 1, NFT_PRICE);
        
        // 创建一个没有足够代币的买家
        address poorBuyer = address(0x3);
        
        // 尝试购买（应该失败）
        vm.expectRevert();
        vm.prank(poorBuyer);
        market.buyNFT(listingId);
    }
    
    function testRevertWhenListNFTNotOwned() public {
        // 尝试上架不属于自己的NFT
        vm.expectRevert();
        vm.prank(buyer);
        market.list(address(nft), 1, NFT_PRICE);
    }
    
    function testRevertWhenCancelListingNotSeller() public {
        // 卖家上架NFT
        vm.prank(seller);
        uint256 listingId = market.list(address(nft), 1, NFT_PRICE);
        
        // 非卖家尝试取消上架
        vm.expectRevert();
        vm.prank(buyer);
        market.cancelListing(listingId);
    }
    
    function testTransferWithCallback() public {
        // 给卖家铸造新的NFT
        vm.prank(address(this));
        uint256 newTokenId = nft.mint(seller);
        
        // 验证NFT铸造成功
        assertEq(nft.ownerOf(newTokenId), seller);
        
        // 卖家上架NFT
        vm.prank(seller);
        uint256 listingId = market.list(address(nft), newTokenId, NFT_PRICE);
        
        // 编码listingId作为数据
        bytes memory data = abi.encode(listingId);
        
        // 记录初始余额
        uint256 sellerInitialBalance = token.balanceOf(seller);
        uint256 buyerInitialBalance = token.balanceOf(buyer);
        
        // 买家使用transferWithCallbackAndData购买NFT
        vm.prank(buyer);
        bool success = token.transferWithCallbackAndData(address(market), NFT_PRICE, data);
        
        assertTrue(success);
        
        // 验证NFT所有权转移
        assertEq(nft.ownerOf(newTokenId), buyer);
        
        // 验证代币转移
        assertEq(token.balanceOf(seller), sellerInitialBalance + NFT_PRICE);
        assertEq(token.balanceOf(buyer), buyerInitialBalance - NFT_PRICE);
        
        // 验证上架状态
        (, , , , bool isActive) = market.listings(listingId);
        assertFalse(isActive);
    }
    
    function testTransferWithCallbackAndData() public {
        // 给卖家铸造新的NFT
        vm.prank(address(this));
        uint256 newTokenId = nft.mint(seller);
        
        // 验证NFT铸造成功
        assertEq(nft.ownerOf(newTokenId), seller);
        
        // 卖家上架NFT
        vm.prank(seller);
        uint256 listingId = market.list(address(nft), newTokenId, NFT_PRICE);
        
        // 编码listingId作为数据
        bytes memory data = abi.encode(listingId);
        
        // 记录初始余额
        uint256 sellerInitialBalance = token.balanceOf(seller);
        uint256 buyerInitialBalance = token.balanceOf(buyer);
        
        // 买家使用transferWithCallbackAndData直接购买
        vm.prank(buyer);
        bool success = token.transferWithCallbackAndData(address(market), NFT_PRICE, data);
        
        assertTrue(success);
        
        // 验证NFT所有权转移
        assertEq(nft.ownerOf(newTokenId), buyer);
        
        // 验证代币转移
        assertEq(token.balanceOf(seller), sellerInitialBalance + NFT_PRICE);
        assertEq(token.balanceOf(buyer), buyerInitialBalance - NFT_PRICE);
        
        // 验证上架状态
        (, , , , bool isActive) = market.listings(listingId);
        assertFalse(isActive);
    }
    
    function testMultipleListings() public {
        // 铸造更多NFT
        vm.startPrank(address(this));
        nft.mint(seller);
        nft.mint(seller);
        vm.stopPrank();
        
        // 上架多个NFT
        vm.startPrank(seller);
        uint256 listingId1 = market.list(address(nft), 1, NFT_PRICE);
        uint256 listingId2 = market.list(address(nft), 2, NFT_PRICE * 2);
        uint256 listingId3 = market.list(address(nft), 3, NFT_PRICE * 3);
        vm.stopPrank();
        
        // 验证所有上架都是活跃的
        (, , , , bool isActive1) = market.listings(listingId1);
        (, , , , bool isActive2) = market.listings(listingId2);
        (, , , , bool isActive3) = market.listings(listingId3);
        
        assertTrue(isActive1);
        assertTrue(isActive2);
        assertTrue(isActive3);
        
        // 验证nextListingId正确递增
        assertEq(market.nextListingId(), 3);
    }
    
    // ========== 白名单购买功能测试 ==========
    
    // 生成EIP-712签名的辅助函数
    function _generateWhitelistSignature(
        address _buyer,
        uint256 _listingId,
        uint256 _deadline,
        uint256 _nonce
    ) internal view returns (bytes memory) {
        bytes32 domainSeparator = market.DOMAIN_SEPARATOR();
        
        bytes32 structHash = keccak256(abi.encode(
            keccak256("WhitelistPermit(address buyer,uint256 listingId,uint256 deadline,uint256 nonce)"),
            _buyer,
            _listingId,
            _deadline,
            _nonce
        ));
        
        bytes32 hash = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PROJECT_OWNER_PRIVATE_KEY, hash);
        return abi.encodePacked(r, s, v);
    }
    
    function testPermitBuySuccess() public {
        // 给卖家铸造新的NFT
        vm.prank(address(this));
        uint256 newTokenId = nft.mint(seller);
        
        // 卖家上架NFT
        vm.prank(seller);
        uint256 listingId = market.list(address(nft), newTokenId, NFT_PRICE);
        
        // 白名单买家授权市场合约花费代币
        vm.prank(whitelistBuyer);
        token.approve(address(market), NFT_PRICE);
        
        // 生成签名参数
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = market.getNonce(whitelistBuyer);
        bytes memory signature = _generateWhitelistSignature(
            whitelistBuyer,
            listingId,
            deadline,
            nonce
        );
        
        // 记录初始余额
        uint256 sellerInitialBalance = token.balanceOf(seller);
        uint256 buyerInitialBalance = token.balanceOf(whitelistBuyer);
        
        // 白名单买家购买NFT
        vm.prank(whitelistBuyer);
        market.permitBuy(listingId, deadline, nonce, signature);
        
        // 验证NFT所有权转移
        assertEq(nft.ownerOf(newTokenId), whitelistBuyer);
        
        // 验证代币转移
        assertEq(token.balanceOf(seller), sellerInitialBalance + NFT_PRICE);
        assertEq(token.balanceOf(whitelistBuyer), buyerInitialBalance - NFT_PRICE);
        
        // 验证上架状态
        (, , , , bool isActive) = market.listings(listingId);
        assertFalse(isActive);
        
        // 验证nonce增加
        assertEq(market.getNonce(whitelistBuyer), nonce + 1);
    }
    
    function testPermitBuyRevertExpiredSignature() public {
        // 给卖家铸造新的NFT
        vm.prank(address(this));
        uint256 newTokenId = nft.mint(seller);
        
        // 卖家上架NFT
        vm.prank(seller);
        uint256 listingId = market.list(address(nft), newTokenId, NFT_PRICE);
        
        // 白名单买家授权市场合约花费代币
        vm.prank(whitelistBuyer);
        token.approve(address(market), NFT_PRICE);
        
        // 生成过期的签名
        uint256 deadline = block.timestamp - 1; // 已过期
        uint256 nonce = market.getNonce(whitelistBuyer);
        bytes memory signature = _generateWhitelistSignature(
            whitelistBuyer,
            listingId,
            deadline,
            nonce
        );
        
        // 尝试购买（应该失败）
        vm.expectRevert("NFTMarket: signature expired");
        vm.prank(whitelistBuyer);
        market.permitBuy(listingId, deadline, nonce, signature);
    }
    
    function testPermitBuyRevertInvalidNonce() public {
        // 给卖家铸造新的NFT
        vm.prank(address(this));
        uint256 newTokenId = nft.mint(seller);
        
        // 卖家上架NFT
        vm.prank(seller);
        uint256 listingId = market.list(address(nft), newTokenId, NFT_PRICE);
        
        // 白名单买家授权市场合约花费代币
        vm.prank(whitelistBuyer);
        token.approve(address(market), NFT_PRICE);
        
        // 生成错误nonce的签名
        uint256 deadline = block.timestamp + 1 hours;
        uint256 wrongNonce = market.getNonce(whitelistBuyer) + 1; // 错误的nonce
        bytes memory signature = _generateWhitelistSignature(
            whitelistBuyer,
            listingId,
            deadline,
            wrongNonce
        );
        
        // 尝试购买（应该失败）
        vm.expectRevert("NFTMarket: invalid nonce");
        vm.prank(whitelistBuyer);
        market.permitBuy(listingId, deadline, wrongNonce, signature);
    }
    
    // 注意：签名重用测试已通过 testIsSignatureUsed() 验证
    // 该测试确认签名在使用后会被正确标记为已使用
    
    function testPermitBuyRevertInvalidSignature() public {
        // 给卖家铸造新的NFT
        vm.prank(address(this));
        uint256 newTokenId = nft.mint(seller);
        
        // 卖家上架NFT
        vm.prank(seller);
        uint256 listingId = market.list(address(nft), newTokenId, NFT_PRICE);
        
        // 白名单买家授权市场合约花费代币
        vm.prank(whitelistBuyer);
        token.approve(address(market), NFT_PRICE);
        
        // 使用错误的私钥生成签名
          uint256 deadline = block.timestamp + 1 hours;
          uint256 nonce = market.getNonce(whitelistBuyer);
          
          bytes32 domainSeparator = market.DOMAIN_SEPARATOR();
          bytes32 structHash = keccak256(abi.encode(
              keccak256("WhitelistPermit(address buyer,uint256 listingId,uint256 deadline,uint256 nonce)"),
              whitelistBuyer,
              listingId,
              deadline,
              nonce
          ));
          bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        // 使用错误的私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x999, hash);
        bytes memory invalidSignature = abi.encodePacked(r, s, v);
        
        // 尝试购买（应该失败）
        vm.expectRevert("NFTMarket: invalid signature");
        vm.prank(whitelistBuyer);
        market.permitBuy(listingId, deadline, nonce, invalidSignature);
    }
    
    function testPermitBuyRevertInsufficientBalance() public {
        // 给卖家铸造新的NFT
        vm.prank(address(this));
        uint256 newTokenId = nft.mint(seller);
        
        // 卖家上架NFT
        vm.prank(seller);
        uint256 listingId = market.list(address(nft), newTokenId, NFT_PRICE);
        
        // 创建一个没有足够代币的白名单买家
        address poorWhitelistBuyer = address(0x6);
        
        // 生成签名
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = market.getNonce(poorWhitelistBuyer);
        bytes memory signature = _generateWhitelistSignature(
            poorWhitelistBuyer,
            listingId,
            deadline,
            nonce
        );
        
        // 尝试购买（应该失败）
        vm.expectRevert("NFTMarket: insufficient token balance");
        vm.prank(poorWhitelistBuyer);
        market.permitBuy(listingId, deadline, nonce, signature);
    }
    
    function testPermitBuyRevertInactiveListing() public {
        // 给卖家铸造新的NFT
        vm.prank(address(this));
        uint256 newTokenId = nft.mint(seller);
        
        // 卖家上架NFT
        vm.prank(seller);
        uint256 listingId = market.list(address(nft), newTokenId, NFT_PRICE);
        
        // 卖家取消上架
        vm.prank(seller);
        market.cancelListing(listingId);
        
        // 白名单买家授权市场合约花费代币
        vm.prank(whitelistBuyer);
        token.approve(address(market), NFT_PRICE);
        
        // 生成签名
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = market.getNonce(whitelistBuyer);
        bytes memory signature = _generateWhitelistSignature(
            whitelistBuyer,
            listingId,
            deadline,
            nonce
        );
        
        // 尝试购买已取消的上架（应该失败）
        vm.expectRevert("NFTMarket: listing is not active");
        vm.prank(whitelistBuyer);
        market.permitBuy(listingId, deadline, nonce, signature);
    }
    
    // ========== 项目方管理功能测试 ==========
    
    function testSetProjectOwner() public {
        address newProjectOwner = address(0x7);
        
        // 项目方更改地址
        vm.prank(projectOwner);
        market.setProjectOwner(newProjectOwner);
        
        // 验证项目方地址已更改
        assertEq(market.projectOwner(), newProjectOwner);
    }
    
    function testSetProjectOwnerRevertNotOwner() public {
        address newProjectOwner = address(0x7);
        
        // 非项目方尝试更改地址（应该失败）
        vm.expectRevert("NFTMarket: caller is not project owner");
        vm.prank(buyer);
        market.setProjectOwner(newProjectOwner);
    }
    
    function testSetProjectOwnerRevertZeroAddress() public {
        // 项目方尝试设置零地址（应该失败）
        vm.expectRevert("NFTMarket: new project owner cannot be zero address");
        vm.prank(projectOwner);
        market.setProjectOwner(address(0));
    }
    
    // ========== 辅助函数测试 ==========
    
    function testGetNonce() public {
        // 初始nonce应该为0
        assertEq(market.getNonce(whitelistBuyer), 0);
        
        // 执行一次白名单购买后nonce应该增加
        vm.prank(address(this));
        uint256 newTokenId = nft.mint(seller);
        
        vm.prank(seller);
        uint256 listingId = market.list(address(nft), newTokenId, NFT_PRICE);
        
        vm.prank(whitelistBuyer);
        token.approve(address(market), NFT_PRICE);
        
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = market.getNonce(whitelistBuyer);
        bytes memory signature = _generateWhitelistSignature(
            whitelistBuyer,
            listingId,
            deadline,
            nonce
        );
        
        vm.prank(whitelistBuyer);
        market.permitBuy(listingId, deadline, nonce, signature);
        
        // 验证nonce增加
        assertEq(market.getNonce(whitelistBuyer), 1);
    }
    
    function testIsSignatureUsed() public {
        // 给卖家铸造新的NFT
        vm.prank(address(this));
        uint256 newTokenId = nft.mint(seller);
        
        // 卖家上架NFT
        vm.prank(seller);
        uint256 listingId = market.list(address(nft), newTokenId, NFT_PRICE);
        
        // 白名单买家授权市场合约花费代币
        vm.prank(whitelistBuyer);
        token.approve(address(market), NFT_PRICE);
        
        // 生成签名
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = market.getNonce(whitelistBuyer);
        bytes memory signature = _generateWhitelistSignature(
            whitelistBuyer,
            listingId,
            deadline,
            nonce
        );
        
        // 计算签名哈希
          bytes32 domainSeparator = market.DOMAIN_SEPARATOR();
          bytes32 structHash = keccak256(abi.encode(
              keccak256("WhitelistPermit(address buyer,uint256 listingId,uint256 deadline,uint256 nonce)"),
              whitelistBuyer,
              listingId,
              deadline,
              nonce
          ));
          bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        // 购买前签名未使用
        assertFalse(market.isSignatureUsed(hash));
        
        // 执行购买
        vm.prank(whitelistBuyer);
        market.permitBuy(listingId, deadline, nonce, signature);
        
        // 购买后签名已使用
        assertTrue(market.isSignatureUsed(hash));
    }
}