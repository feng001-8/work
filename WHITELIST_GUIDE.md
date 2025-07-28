# NFT 白名单购买功能使用指南

## 功能概述

`permitBuy()` 函数实现了基于 EIP-712 签名的白名单购买机制，只有获得项目方离线授权的地址才能购买特定的 NFT。

## 核心特性

- **离线授权**: 项目方可以离线生成签名，无需链上交易
- **防重放攻击**: 使用 nonce 和签名哈希防止重复使用
- **时间限制**: 支持签名过期时间设置
- **灵活控制**: 项目方可以精确控制谁能购买哪个 NFT

## 合约接口

### permitBuy 函数

```solidity
function permitBuy(
    uint256 _listingId,    // NFT 上架 ID
    uint256 _deadline,     // 签名过期时间戳
    uint256 _nonce,        // 用户当前 nonce
    bytes calldata _signature // 项目方签名
) external
```

### 辅助函数

```solidity
// 获取用户当前 nonce
function getNonce(address _user) external view returns (uint256)

// 检查签名是否已被使用
function isSignatureUsed(bytes32 _hash) external view returns (bool)

// 设置项目方地址（仅限当前项目方）
function setProjectOwner(address _newProjectOwner) external
```

## 使用流程

### 1. 项目方生成签名

项目方需要为每个白名单用户生成签名：

```javascript
const whitelistData = {
    buyer: '0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6', // 白名单用户地址
    listingId: 1,                                      // NFT listing ID
    deadline: Math.floor(Date.now() / 1000) + 3600,   // 1小时后过期
    nonce: 0                                           // 用户当前nonce
};

const signature = await projectOwnerWallet._signTypedData(domain, types, whitelistData);
```

### 2. 用户调用 permitBuy

白名单用户使用项目方提供的签名购买 NFT：

```solidity
// 首先需要授权代币给合约
token.approve(nftMarketAddress, price);

// 然后调用白名单购买
nftMarket.permitBuy(listingId, deadline, nonce, signature);
```

## EIP-712 签名结构

### 域分隔符 (Domain Separator)

```javascript
const domain = {
    name: 'NFTMarket',
    version: '1',
    chainId: 1, // 根据实际网络修改
    verifyingContract: nftMarketAddress
};
```

### 类型定义 (Types)

```javascript
const types = {
    WhitelistPermit: [
        { name: 'buyer', type: 'address' },
        { name: 'listingId', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
        { name: 'nonce', type: 'uint256' }
    ]
};
```

## 安全机制

### 1. 防重放攻击

- **用户 nonce**: 每次成功购买后，用户的 nonce 会自动增加
- **签名哈希记录**: 每个签名只能使用一次

### 2. 时间限制

- 签名包含过期时间，超时后自动失效
- 建议设置合理的过期时间（如1-24小时）

### 3. 权限控制

- 只有项目方的签名才有效
- 项目方地址可以通过 `setProjectOwner` 更改

## 事件监听

### WhitelistNFTSold 事件

```solidity
event WhitelistNFTSold(
    uint256 indexed listingId,
    address indexed buyer,
    address indexed seller,
    address nftContract,
    uint256 tokenId,
    uint256 price
);
```

### ProjectOwnerChanged 事件

```solidity
event ProjectOwnerChanged(
    address indexed oldOwner,
    address indexed newOwner
);
```

## 错误处理

常见错误及解决方案：

- `"NFTMarket: signature expired"`: 签名已过期，需要重新生成
- `"NFTMarket: listing is not active"`: NFT 已被购买或下架
- `"NFTMarket: insufficient token balance"`: 买家代币余额不足
- `"NFTMarket: invalid nonce"`: nonce 不正确，需要获取最新 nonce
- `"NFTMarket: signature already used"`: 签名已被使用
- `"NFTMarket: invalid signature"`: 签名无效或非项目方签名

## 最佳实践

1. **签名管理**: 项目方应该建立完善的签名生成和分发系统
2. **过期时间**: 设置合理的签名过期时间，平衡安全性和用户体验
3. **nonce 同步**: 确保前端能够获取用户最新的 nonce 值
4. **错误处理**: 前端应该妥善处理各种错误情况
5. **事件监听**: 监听相关事件以更新 UI 状态

## 示例代码

完整的签名生成和验证示例请参考 `whitelist-signature-example.js` 文件。

## 与普通购买的区别

| 功能     | buyNFT() | permitBuy()      |
| -------- | -------- | ---------------- |
| 购买权限 | 任何人   | 仅白名单用户     |
| 授权方式 | 无需授权 | 需要项目方签名   |
| 防重放   | 无       | nonce + 签名哈希 |
| 时间限制 | 无       | 支持过期时间     |
| 使用场景 | 公开销售 | 私人销售/预售    |

这个白名单机制为 NFT 市场提供了更灵活的销售控制，特别适用于预售、VIP 销售等场景。
