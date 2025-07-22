// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/ERC20.sol";
import "../src/SimpleNFT.sol";
import { NFTMarket } from "../src/nftMarket.sol";

contract DeployNFTMarket is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署ERC20代币合约
        BaseERC20 token = new BaseERC20();
        console.log("ERC20 Token deployed to:", address(token));
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
        console.log("Total supply:", token.totalSupply());

        // 2. 部署NFT合约
        SimpleNFT nft = new SimpleNFT("Test NFT", "TNFT");
        console.log("NFT Contract deployed to:", address(nft));
        console.log("NFT name:", nft.name());
        console.log("NFT symbol:", nft.symbol());

        // 3. 部署NFT市场合约
        NFTMarket market = new NFTMarket(address(token));
        console.log("NFT Market deployed to:", address(market));
        console.log("Payment token address:", address(market.paymentToken()));

        // 4. 铸造一些测试NFT
        address deployer = vm.addr(deployerPrivateKey);
        uint256[] memory tokenIds = nft.batchMint(deployer, 5);
        console.log("Minted NFTs with IDs:");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            console.log("  Token ID:", tokenIds[i]);
        }

        // 5. 授权市场合约操作NFT
        nft.setApprovalForAll(address(market), true);
        console.log("Approved NFT Market to operate all NFTs");

        // 6. 上架第一个NFT
        uint256 price = 1000 * 10**18; // 1000 tokens
        uint256 listingId = market.list(address(nft), tokenIds[0], price);
        console.log("Listed NFT with ID:", tokenIds[0]);
        console.log("Listing ID:", listingId);
        console.log("Price:", price);

        vm.stopBroadcast();

        // 输出部署信息
        console.log("\n=== Deployment Summary ===");
        console.log("ERC20 Token:", address(token));
        console.log("NFT Contract:", address(nft));
        console.log("NFT Market:", address(market));
        console.log("Deployer:", deployer);
        console.log("\n=== Usage Instructions ===");
        console.log("1. Use the ERC20 token to buy NFTs from the market");
        console.log("2. Approve the market contract to spend your tokens before buying");
        console.log("3. Use buyNFT() or buyNFTWithCallback() to purchase NFTs");
        console.log("4. Mint more NFTs using the SimpleNFT contract");
        console.log("5. List NFTs for sale using the market contract");
    }
}