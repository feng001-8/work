// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ILAUNCHPAD.sol";
import "./LAUNCHPad.sol";
import "./StartToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title LaunchPadFactory
 * @dev 启动板工厂合约，负责创建和管理启动板实例
 * @notice 该合约使用工厂模式创建多个启动板合约，实现代币发行平台功能
 */
contract LaunchPadFactory is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // ======================================================================== 
    // --------------------------- 事件定义 ----------------------------------- 
    // ======================================================================== 
    
    /// @dev 启动板注册成功事件
    event LaunchPadRegistered(
        address indexed padToken, 
        uint256 indexed regId,
        address indexed admin,
        uint256 startTime
    );
    
    /// @dev 启动板创建成功事件
    event LaunchPadCreated(
        address indexed launchPadAddress,
        address indexed moderator,
        address indexed padToken,
        uint256 padDuration,
        uint256 launchPadSupply,
        uint256 presaleSupply
    );
    
    /// @dev 工厂设置更新事件
    event FactorySettingsUpdated(
        address indexed admin,
        uint256 newFee
    );
    
    /// @dev ETH提取事件
    event EthWithdrawn(
        address indexed admin,
        uint256 amount
    );

    // ======================================================================== 
    // --------------------------- 错误定义 ----------------------------------- 
    // ======================================================================== 
    
    /// @dev 注册ID已被占用错误
    error Id_Already_Taken();
    /// @dev 地址不能为零地址错误
    error Cannot_Be_Address_Zero();
    /// @dev 不能接受零值错误
    error Cannot_Accept_Zero_Value();
    /// @dev 无效的注册ID错误
    error Invalid_Registration_Id();
    /// @dev 未注册的管理员错误
    error Not_Registered_Admin();
    /// @dev 注册尚未开放错误
    error Registration_Not_Open_Yet();
    /// @dev 代币未注册错误
    error Token_Not_Registered();
    /// @dev 不是项目管理员错误
    error Not_Project_Admin();
    /// @dev 代币转账失败错误
    error Token_Transfer_Failed();
    /// @dev 无效的手续费百分比错误
    error Invalid_Fee_Percentage();
    /// @dev ETH转账失败错误
    error Eth_Transfer_Failed();

    // ======================================================================== 
    // --------------------------- 状态变量 ----------------------------------- 
    // ======================================================================== 
    
    /// @dev 存储所有创建的启动板地址
    address[] public launchPads;
    /// @dev 项目管理员地址
    address public projectAdmin;
    /// @dev 启动板手续费百分比
    uint256 public launchPadFee;
    /// @dev 工厂合约版本
    string public constant VERSION = "1.0.0";
    
    /// @dev 启动板详细信息结构体
    struct PadDetails {
        uint256 launchPadStartTime;    // 启动板开始时间
        address launchPadAddress;      // 启动板合约地址
        address launchPadAdmin;        // 启动板管理员地址
        address padToken;              // 代币合约地址
        uint256 totalSupply;           // 总供应量
        uint256 presaleSupply;         // 预售供应量
        bool isActive;                 // 是否激活
    }
    
    // ======================================================================== 
    // --------------------------- 映射存储 ----------------------------------- 
    // ======================================================================== 
    
    /// @dev 记录ID是否已被使用
    mapping(uint256 => bool) public idIsTaken;
    /// @dev 代币地址到启动板ID的映射
    mapping(address => uint256) public launchPadIdRecord;
    /// @dev 启动板ID到详细信息的映射
    mapping(uint256 => PadDetails) public launchPadRecord;
    /// @dev 代币地址到启动板地址的映射
    mapping(address => address) public tokenToLaunchPadRecord;
    /// @dev 管理员地址到其创建的启动板数量的映射
    mapping(address => uint256) public adminLaunchPadCount;
    /// @dev 管理员地址到其创建的启动板地址列表的映射
    mapping(address => address[]) public adminLaunchPads;

    // ======================================================================== 
    // --------------------------- 修饰符 ------------------------------------- 
    // ======================================================================== 
    
    /**
     * @dev 只有项目管理员可以调用的修饰符
     */
    modifier onlyAdmin() {
        if (msg.sender != projectAdmin) revert Not_Project_Admin();
        _;
    }

    /**
     * @dev 只有已验证的启动板管理员可以调用的修饰符
     * @param regId 注册ID
     * @param _padToken 代币地址
     */
    modifier onlyVerifiedAdmin(uint256 regId, address _padToken) {
        if (!idIsTaken[regId]) revert Invalid_Registration_Id();
        if (launchPadRecord[regId].launchPadAdmin != msg.sender) revert Not_Registered_Admin();
        if (launchPadRecord[regId].launchPadStartTime > block.timestamp) revert Registration_Not_Open_Yet();
        if (launchPadIdRecord[_padToken] != regId) revert Token_Not_Registered();
        _;
    }

    // ======================================================================== 
    // --------------------------- 构造函数 ----------------------------------- 
    // ======================================================================== 
    
    /**
     * @dev 构造函数，初始化工厂合约
     * @param admin 项目管理员地址
     * @param _launchPadFees 启动板手续费百分比
     */
    constructor(address admin, uint256 _launchPadFees) {
        if (admin == address(0)) revert Cannot_Be_Address_Zero();
        if (_launchPadFees > 100) revert Invalid_Fee_Percentage();
        
        projectAdmin = admin;
        launchPadFee = _launchPadFees;
    }

    // ======================================================================== 
    // --------------------------- 核心功能函数 ------------------------------- 
    // ======================================================================== 
    
    /**
     * @dev 注册启动板项目
     * @param _launchPadAdmin 启动板管理员地址
     * @param padToken 要发行的代币地址
     * @param regId 注册ID，必须唯一且不为0
     * @param _startTime 启动板开始时间戳
     * @notice 只有项目管理员可以调用此函数注册启动板项目
     */
    function registerLaunchPad(
        address _launchPadAdmin,
        address padToken,
        uint256 regId,
        uint256 _startTime
    ) external onlyAdmin {
        if (regId == 0) revert Cannot_Accept_Zero_Value();
        if (_launchPadAdmin == address(0) || padToken == address(0)) revert Cannot_Be_Address_Zero();
        if (idIsTaken[regId]) revert Id_Already_Taken();
        if (_startTime < block.timestamp) revert Invalid_Registration_Id();
        
        // 记录注册信息
        launchPadIdRecord[padToken] = regId;
        launchPadRecord[regId].launchPadAdmin = _launchPadAdmin;
        launchPadRecord[regId].launchPadStartTime = _startTime;
        launchPadRecord[regId].padToken = padToken;
        launchPadRecord[regId].isActive = true;
        idIsTaken[regId] = true;
        
        emit LaunchPadRegistered(padToken, regId, _launchPadAdmin, _startTime);
    }

    /**
     * @dev 创建启动板合约实例
     * @param regId 注册ID
     * @param _padToken 代币合约地址
     * @param _launchPadTSupply 启动板代币供应量
     * @param _preSaleTokenSupply 预售代币供应量
     * @param _padDuration 启动板持续时间（分钟）
     * @param _percentagePresalePriceIncrease 预售价格增长百分比
     * @notice 只有已注册的管理员可以调用，创建具体的启动板合约
     */
    function createLaunchPad(
        uint256 regId,
        address _padToken,
        uint256 _launchPadTSupply,
        uint256 _preSaleTokenSupply,
        uint256 _padDuration,
        uint256 _percentagePresalePriceIncrease
    ) external onlyVerifiedAdmin(regId, _padToken) nonReentrant {
        // 参数验证
        if (_launchPadTSupply == 0 || _preSaleTokenSupply == 0) revert Cannot_Accept_Zero_Value();
        if (_padDuration == 0 || _percentagePresalePriceIncrease == 0) revert Cannot_Accept_Zero_Value();
        
        // 创建启动板合约
        LAUNCHPad newLaunchPad = new LAUNCHPad(
            projectAdmin,           // 合约监督者
            launchPadFee,          // 启动板手续费
            address(this),         // 手续费接收地址
            msg.sender,            // 启动板管理员
            _padToken,             // 代币地址
            _padDuration,          // 持续时间
            _launchPadTSupply,     // 启动板供应量
            _preSaleTokenSupply,   // 预售供应量
            _percentagePresalePriceIncrease  // 价格增长百分比
        );
        
        // 计算需要转移的代币总量
        uint256 totalTokens = _launchPadTSupply.add(_preSaleTokenSupply);
        
        // 从管理员地址转移代币到启动板合约
        IERC20(_padToken).safeTransferFrom(
            msg.sender,
            address(newLaunchPad),
            totalTokens
        );
        
        // 更新记录
        address launchPadAddress = address(newLaunchPad);
        launchPads.push(launchPadAddress);
        launchPadRecord[regId].launchPadAddress = launchPadAddress;
        launchPadRecord[regId].totalSupply = _launchPadTSupply;
        launchPadRecord[regId].presaleSupply = _preSaleTokenSupply;
        tokenToLaunchPadRecord[_padToken] = launchPadAddress;
        
        // 更新管理员统计
        adminLaunchPadCount[msg.sender] = adminLaunchPadCount[msg.sender].add(1);
        adminLaunchPads[msg.sender].push(launchPadAddress);
        
        emit LaunchPadCreated(
            launchPadAddress,
            msg.sender,
            _padToken,
            _padDuration,
            _launchPadTSupply,
            _preSaleTokenSupply
        );
    }

    // ======================================================================== 
    // --------------------------- 管理员函数 --------------------------------- 
    // ======================================================================== 
    
    /**
     * @dev 设置启动板手续费
     * @param _amount 新的手续费百分比
     * @notice 只有项目管理员可以调用
     */
    function setLaunchPadFee(uint256 _amount) external onlyAdmin {
        if (_amount > 100) revert Invalid_Fee_Percentage();
        launchPadFee = _amount;
        emit FactorySettingsUpdated(msg.sender, _amount);
    }
    
    /**
     * @dev 更新项目管理员地址
     * @param newAdmin 新的管理员地址
     * @notice 只有当前项目管理员可以调用
     */
    function updateProjectAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert Cannot_Be_Address_Zero();
        projectAdmin = newAdmin;
    }
    
    /**
     * @dev 停用指定的启动板注册
     * @param regId 注册ID
     * @notice 只有项目管理员可以调用
     */
    function deactivateLaunchPad(uint256 regId) external onlyAdmin {
        if (!idIsTaken[regId]) revert Invalid_Registration_Id();
        launchPadRecord[regId].isActive = false;
    }

    /**
     * @dev 提取合约中的ETH
     * @param _amount 要提取的ETH数量
     * @notice 只有项目管理员可以调用
     */
    function withdrawEth(uint256 _amount) external onlyAdmin nonReentrant {
        if (_amount == 0) revert Cannot_Accept_Zero_Value();
        if (address(this).balance < _amount) revert Eth_Transfer_Failed();
        
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if (!success) revert Eth_Transfer_Failed();
        
        emit EthWithdrawn(msg.sender, _amount);
    }

    // ======================================================================== 
    // --------------------------- 查询函数 ----------------------------------- 
    // ======================================================================== 
    
    /**
     * @dev 获取所有启动板地址
     * @return 启动板地址数组
     */
    function getLaunchPads() external view returns (address[] memory) {
        return launchPads;
    }
    
    /**
     * @dev 获取启动板总数
     * @return 启动板总数
     */
    function getLaunchPadCount() external view returns (uint256) {
        return launchPads.length;
    }

    /**
     * @dev 根据代币地址获取对应的启动板地址
     * @param tokenAddress 代币合约地址
     * @return 启动板合约地址
     */
    function getLaunchPadAddress(address tokenAddress) external view returns (address) {
        return tokenToLaunchPadRecord[tokenAddress];
    }
    
    /**
     * @dev 根据注册ID获取启动板详细信息
     * @param regId 注册ID
     * @return 启动板详细信息
     */
    function getLaunchPadDetails(uint256 regId) external view returns (PadDetails memory) {
        return launchPadRecord[regId];
    }
    
    /**
     * @dev 获取管理员创建的启动板列表
     * @param admin 管理员地址
     * @return 启动板地址数组
     */
    function getAdminLaunchPads(address admin) external view returns (address[] memory) {
        return adminLaunchPads[admin];
    }
    
    /**
     * @dev 获取管理员创建的启动板数量
     * @param admin 管理员地址
     * @return 启动板数量
     */
    function getAdminLaunchPadCount(address admin) external view returns (uint256) {
        return adminLaunchPadCount[admin];
    }
    
    /**
     * @dev 检查注册ID是否可用
     * @param regId 注册ID
     * @return 是否可用
     */
    function isRegistrationIdAvailable(uint256 regId) external view returns (bool) {
        return !idIsTaken[regId] && regId != 0;
    }
    
    /**
     * @dev 获取工厂合约的基本信息
     * @return admin 项目管理员地址
     * @return fee 手续费百分比
     * @return totalLaunchPads 总启动板数量
     * @return version 合约版本
     */
    function getFactoryInfo() external view returns (
        address admin,
        uint256 fee,
        uint256 totalLaunchPads,
        string memory version
    ) {
        return (
            projectAdmin,
            launchPadFee,
            launchPads.length,
            VERSION
        );
    }

    // ======================================================================== 
    // --------------------------- 接收函数 ----------------------------------- 
    // ======================================================================== 
    
    /**
     * @dev 接收ETH的函数
     */
    receive() external payable {
        // 允许合约接收ETH
    }
    
    /**
     * @dev 回退函数
     */
    fallback() external payable {
        revert("Function not found");
    }
}