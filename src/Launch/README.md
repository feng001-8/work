# LaunchPad Factory 启动板工厂合约

## 概述

`LaunchPadFactory.sol` 是一个基于工厂模式的智能合约，用于创建和管理多个启动板（LaunchPad）实例。该合约提供了完整的代币发行平台功能，支持预售和正式发行阶段。

## 主要功能

### 1. 启动板注册
- 项目管理员可以注册新的启动板项目
- 每个项目需要唯一的注册ID
- 支持设置启动时间和管理员权限

### 2. 启动板创建
- 已注册的管理员可以创建具体的启动板合约实例
- 自动处理代币转移到启动板合约
- 支持预售和正式发行两个阶段

### 3. 管理功能
- 设置和调整手续费
- 提取合约中的ETH
- 停用指定的启动板
- 更新项目管理员

### 4. 查询功能
- 获取所有启动板列表
- 根据代币地址查询启动板
- 获取管理员创建的启动板统计
- 检查注册ID可用性

## 合约架构

```
LaunchPadFactory
├── 注册管理
│   ├── registerLaunchPad() - 注册启动板项目
│   └── deactivateLaunchPad() - 停用启动板
├── 创建管理
│   └── createLaunchPad() - 创建启动板实例
├── 系统管理
│   ├── setLaunchPadFee() - 设置手续费
│   ├── updateProjectAdmin() - 更新管理员
│   └── withdrawEth() - 提取ETH
└── 查询接口
    ├── getLaunchPads() - 获取所有启动板
    ├── getLaunchPadDetails() - 获取启动板详情
    └── getFactoryInfo() - 获取工厂信息
```

## 使用流程

### 1. 部署工厂合约
```solidity
// 部署参数：管理员地址，手续费百分比
LaunchPadFactory factory = new LaunchPadFactory(adminAddress, 5); // 5%手续费
```

### 2. 注册启动板项目
```solidity
// 只有项目管理员可以调用
factory.registerLaunchPad(
    launchPadAdmin,  // 启动板管理员地址
    tokenAddress,    // 代币合约地址
    registrationId,  // 唯一注册ID
    startTime        // 启动时间戳
);
```

### 3. 创建启动板实例
```solidity
// 启动板管理员调用，需要先授权代币
IERC20(tokenAddress).approve(factoryAddress, totalTokenAmount);

factory.createLaunchPad(
    registrationId,              // 注册ID
    tokenAddress,                // 代币地址
    launchPadSupply,            // 启动板供应量
    presaleSupply,              // 预售供应量
    duration,                   // 持续时间（分钟）
    priceIncreasePercentage     // 预售价格增长百分比
);
```

## 安全特性

- **重入攻击防护**: 使用 `ReentrancyGuard` 保护关键函数
- **权限控制**: 严格的管理员权限验证
- **参数验证**: 全面的输入参数检查
- **安全转账**: 使用 `SafeERC20` 进行代币操作
- **事件记录**: 完整的操作事件日志

## 事件

- `LaunchPadRegistered`: 启动板注册成功
- `LaunchPadCreated`: 启动板创建成功
- `FactorySettingsUpdated`: 工厂设置更新
- `EthWithdrawn`: ETH提取

## 错误类型

- `Id_Already_Taken`: 注册ID已被占用
- `Cannot_Be_Address_Zero`: 地址不能为零地址
- `Cannot_Accept_Zero_Value`: 不能接受零值
- `Invalid_Registration_Id`: 无效的注册ID
- `Not_Registered_Admin`: 未注册的管理员
- `Registration_Not_Open_Yet`: 注册尚未开放
- `Token_Not_Registered`: 代币未注册
- `Not_Project_Admin`: 不是项目管理员
- `Invalid_Fee_Percentage`: 无效的手续费百分比
- `Eth_Transfer_Failed`: ETH转账失败

## 依赖合约

- `ILAUNCHPAD.sol`: 启动板接口定义
- `LAUNCHPad.sol`: 启动板合约实现
- `StartToken.sol`: 代币合约
- OpenZeppelin 库：安全性和标准实现

## 版本信息

- Solidity: ^0.8.0
- 合约版本: 1.0.0
- OpenZeppelin: 最新稳定版

## 注意事项

1. 部署前确保所有依赖合约已正确部署
2. 创建启动板前需要先授权足够的代币给工厂合约
3. 注册ID必须唯一且不为0
4. 手续费百分比不能超过100%
5. 启动时间必须是未来的时间戳

## Gas 优化

- 使用 `SafeMath` 进行安全的数学运算
- 合理的存储布局减少gas消耗
- 批量操作减少交易次数
- 事件日志用于链下数据索引