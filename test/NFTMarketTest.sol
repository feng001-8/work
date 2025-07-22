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
    
    uint256 public constant INITIAL_BALANCE = 1000000 * 10**18;
    uint256 public constant NFT_PRICE = 100 * 10**18;
    
    function setUp() public {
        // 部署合约
        token = new BaseERC20();
        nft = new SimpleNFT("Test NFT", "TNFT");
        market = new NFTMarket(address(token));
        
        // 给卖家和买家分配代币
        vm.prank(address(this));
        token.transfer(seller, INITIAL_BALANCE);
        vm.prank(address(this));
        token.transfer(buyer, INITIAL_BALANCE);
        
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
}