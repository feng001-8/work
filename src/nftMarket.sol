// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 导入OpenZeppelin的ECDSA库用于签名验证
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

// 导入IERC20接口，用于与ERC20代币交互
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

// 定义接收代币回调的接口
interface ITokenReceiver {
    function tokensReceived(address from, uint256 amount, bytes calldata data) external returns (bool);
}

// 简单的ERC721接口
interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function getApproved(uint256 tokenId) external view returns (address);
}

// 扩展的ERC20接口，添加带有回调功能的转账函数
interface IExtendedERC20 is IERC20 {
    function transferWithCallback(address _to, uint256 _value) external returns (bool);
    function transferWithCallbackAndData(address _to, uint256 _value, bytes calldata _data) external returns (bool);
}

// NFT市场合约
contract NFTMarket is ITokenReceiver, EIP712 {
    using ECDSA for bytes32;
    
    // 白名单许可结构体
    struct WhitelistPermit {
        address buyer;        // 白名单用户地址
        uint256 listingId;    // 允许购买的 NFT listing ID
        uint256 deadline;     // 签名过期时间
        uint256 nonce;        // 防重放随机数
    }
    
    // EIP-712 类型哈希
    bytes32 private constant WHITELIST_PERMIT_TYPEHASH = keccak256(
        "WhitelistPermit(address buyer,uint256 listingId,uint256 deadline,uint256 nonce)"
    );
    
    // 项目方地址（有权签发白名单的地址）
    address public projectOwner;
    
    // 用户nonce映射，防止重放攻击
    mapping(address => uint256) public nonces;
    
    // 已使用的签名映射，防止签名重复使用
    mapping(bytes32 => bool) public usedSignatures;
    // 扩展的ERC20代币合约地址
    IExtendedERC20 public paymentToken;
    
    // NFT上架信息结构体
    struct Listing {
        address seller;      // 卖家地址
        address nftContract; // NFT合约地址
        uint256 tokenId;     // NFT的tokenId
        uint256 price;       // 价格（以Token为单位）
        bool isActive;       // 是否处于活跃状态
    }
    
    // 所有上架的NFT，使用listingId作为唯一标识
    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId;
    
    // NFT上架和购买事件
    event NFTListed(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);
    event NFTSold(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event NFTListingCancelled(uint256 indexed listingId);
    event WhitelistNFTSold(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event ProjectOwnerChanged(address indexed oldOwner, address indexed newOwner);
    
    // 构造函数，设置支付代币地址和项目方地址
    constructor(address _paymentTokenAddress, address _projectOwner) 
        EIP712("NFTMarket", "1") 
    {
        require(_paymentTokenAddress != address(0), "NFTMarket: payment token address cannot be zero");
        require(_projectOwner != address(0), "NFTMarket: project owner address cannot be zero");
        paymentToken = IExtendedERC20(_paymentTokenAddress);
        projectOwner = _projectOwner;
    }
    
    // 上架NFT
    function list(address _nftContract, uint256 _tokenId, uint256 _price) external returns (uint256) {
        // 检查价格是否大于0
        require(_price > 0, "NFTMarket: price must be greater than zero");
        
        // 检查NFT合约地址是否有效
        require(_nftContract != address(0), "NFTMarket: NFT contract address cannot be zero");
        
        // 检查调用者是否为NFT的所有者或已获得授权
        IERC721 nftContract = IERC721(_nftContract);
        address owner = nftContract.ownerOf(_tokenId);
        require(
            owner == msg.sender || 
            nftContract.isApprovedForAll(owner, msg.sender) || 
            nftContract.getApproved(_tokenId) == msg.sender,
            "NFTMarket: caller is not owner nor approved"
        );
        
        // 创建新的上架信息
        uint256 listingId = nextListingId;
        listings[listingId] = Listing({
            seller: owner,
            nftContract: _nftContract,
            tokenId: _tokenId,
            price: _price,
            isActive: true
        });
        
        // 增加listingId计数器
        nextListingId++;
        
        // 触发NFT上架事件
        emit NFTListed(listingId, owner, _nftContract, _tokenId, _price);
        
        return listingId;
    }
    
    // 取消上架NFT
    function cancelListing(uint256 _listingId) external {
        // 检查上架信息是否存在且处于活跃状态
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "NFTMarket: listing is not active");
        
        // 检查调用者是否为卖家
        require(listing.seller == msg.sender, "NFTMarket: caller is not the seller");
        
        // 将上架信息标记为非活跃
        listing.isActive = false;
        
        // 触发NFT上架取消事件
        emit NFTListingCancelled(_listingId);
    }
    
    // 普通购买NFT功能
    function buyNFT(uint256 _listingId) external {
        // 检查上架信息是否存在且处于活跃状态
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "NFTMarket: listing is not active");
        
        // 检查买家是否有足够的代币
        require(paymentToken.balanceOf(msg.sender) >= listing.price, "NFTMarket: insufficient token balance");
        
        // 将上架信息标记为非活跃
        listing.isActive = false;
        
        // 处理代币转账（买家 -> 卖家）
        bool success = paymentToken.transferFrom(msg.sender, listing.seller, listing.price);
        require(success, "NFTMarket: token transfer failed");
        
        // 处理NFT转移（卖家 -> 买家）
        IERC721(listing.nftContract).transferFrom(listing.seller, msg.sender, listing.tokenId);
        
        // 触发NFT售出事件
        emit NFTSold(_listingId, msg.sender, listing.seller, listing.nftContract, listing.tokenId, listing.price);
    }
    
    // 实现tokensReceived接口，处理通过transferWithCallback接收到的代币
    function tokensReceived(address from, uint256 amount, bytes calldata data) external override returns (bool) {
        // 检查调用者是否为支付代币合约
        require(msg.sender == address(paymentToken), "NFTMarket: caller is not the payment token contract");
        
        // 解析附加数据，获取listingId
        require(data.length == 32, "NFTMarket: invalid data length");
        uint256 listingId = abi.decode(data, (uint256));
        
        // 检查上架信息是否存在且处于活跃状态
        Listing storage listing = listings[listingId];
        require(listing.isActive, "NFTMarket: listing is not active");
        
        // 检查转入的代币数量是否等于NFT价格
        require(amount == listing.price, "NFTMarket: incorrect payment amount");
        
        // 将上架信息标记为非活跃
        listing.isActive = false;
        
        // 将代币转给卖家（从市场合约转出）
        bool success = paymentToken.transfer(listing.seller, amount);
        require(success, "NFTMarket: token transfer to seller failed");
        
        // 处理NFT转移（卖家 -> 买家）
        IERC721(listing.nftContract).transferFrom(listing.seller, from, listing.tokenId);
        
        // 触发NFT售出事件
        emit NFTSold(listingId, from, listing.seller, listing.nftContract, listing.tokenId, amount);
        
        return true;
    }
    
    // 使用transferWithCallbackAndData购买NFT的辅助函数
    function buyNFTWithCallback(uint256 _listingId) external {
        // 检查上架信息是否存在且处于活跃状态
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "NFTMarket: listing is not active");
        
        // 检查买家是否有足够的代币
        require(paymentToken.balanceOf(msg.sender) >= listing.price, "NFTMarket: insufficient token balance");
        
        // 将上架信息标记为非活跃
        listing.isActive = false;
        
        // 直接从买家转账给卖家
        bool success = paymentToken.transferFrom(msg.sender, listing.seller, listing.price);
        require(success, "NFTMarket: token transfer failed");
        
        // 处理NFT转移（卖家 -> 买家）
        IERC721(listing.nftContract).transferFrom(listing.seller, msg.sender, listing.tokenId);
        
        // 触发NFT售出事件
        emit NFTSold(_listingId, msg.sender, listing.seller, listing.nftContract, listing.tokenId, listing.price);
    }
    
    // 白名单购买NFT函数
    function permitBuy(
        uint256 _listingId,
        uint256 _deadline,
        uint256 _nonce,
        bytes calldata _signature
    ) external {
        // 检查签名是否过期
        require(block.timestamp <= _deadline, "NFTMarket: signature expired");
        
        // 检查上架信息是否存在且处于活跃状态
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "NFTMarket: listing is not active");
        
        // 检查买家是否有足够的代币
        require(paymentToken.balanceOf(msg.sender) >= listing.price, "NFTMarket: insufficient token balance");
        
        // 检查nonce是否正确（防止重放攻击）
        require(_nonce == nonces[msg.sender], "NFTMarket: invalid nonce");
        
        // 构造签名数据
        WhitelistPermit memory permit = WhitelistPermit({
            buyer: msg.sender,
            listingId: _listingId,
            deadline: _deadline,
            nonce: _nonce
        });
        
        // 计算结构化数据哈希
        bytes32 structHash = keccak256(abi.encode(
            WHITELIST_PERMIT_TYPEHASH,
            permit.buyer,
            permit.listingId,
            permit.deadline,
            permit.nonce
        ));
        
        // 计算EIP-712哈希
        bytes32 hash = _hashTypedDataV4(structHash);
        
        // 检查签名是否已被使用
        require(!usedSignatures[hash], "NFTMarket: signature already used");
        
        // 恢复签名者地址
        address signer = hash.recover(_signature);
        
        // 验证签名者是否为项目方
        require(signer == projectOwner, "NFTMarket: invalid signature");
        
        // 标记签名已使用
        usedSignatures[hash] = true;
        
        // 增加用户nonce
        nonces[msg.sender]++;
        
        // 将上架信息标记为非活跃
        listing.isActive = false;
        
        // 处理代币转账（买家 -> 卖家）
        bool success = paymentToken.transferFrom(msg.sender, listing.seller, listing.price);
        require(success, "NFTMarket: token transfer failed");
        
        // 处理NFT转移（卖家 -> 买家）
        IERC721(listing.nftContract).transferFrom(listing.seller, msg.sender, listing.tokenId);
        
        // 触发白名单NFT售出事件
        emit WhitelistNFTSold(_listingId, msg.sender, listing.seller, listing.nftContract, listing.tokenId, listing.price);
    }
    
    // 设置项目方地址（仅限当前项目方）
    function setProjectOwner(address _newProjectOwner) external {
        require(msg.sender == projectOwner, "NFTMarket: caller is not project owner");
        require(_newProjectOwner != address(0), "NFTMarket: new project owner cannot be zero address");
        
        address oldOwner = projectOwner;
        projectOwner = _newProjectOwner;
        
        emit ProjectOwnerChanged(oldOwner, _newProjectOwner);
    }
    
    // 获取用户当前nonce
    function getNonce(address _user) external view returns (uint256) {
        return nonces[_user];
    }
    
    // 检查签名是否已被使用
    function isSignatureUsed(bytes32 _hash) external view returns (bool) {
        return usedSignatures[_hash];
    }
}