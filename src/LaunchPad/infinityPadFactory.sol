// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IUSDT.sol";
import "./infinityDaoPad.sol";

/**
 * @title InfinityDaoLaunchPadFactory
 * @dev 启动板工厂合约，负责创建和管理启动板实例
 * @notice 该合约使用工厂模式创建多个启动板合约，实现代币发行平台功能
 */
contract InfinityDaoLaunchPadFactory {
    /// @dev 启动板注册成功事件
    event LaunchPadRegistered(address PadToken, uint regId);
    
    /// @dev 启动板创建成功事件
    event launchpadCreated(
        address moderator,
        address padtoken,
        uint padDuration
    );
    
    /// @dev 注册ID已被占用错误
    error Id_Already_Taken();
    /// @dev 地址不能为零地址错误
    error Cannot_Be_Address_Zero();
    /// @dev 不能接受零值错误
    error cannot_Accept_Zero_Value();

    /// @dev 存储所有创建的启动板地址
    address[] launchpads;
    /// @dev 项目管理员地址
    address ProjectAdmin;

    /// @dev 启动板手续费百分比
    uint launchPadFee;
    
    /// @dev 启动板详细信息结构体
    struct padDetails {
        uint LaunchPadStartTime;    // 启动板开始时间
        address LaunchpadAddress;   // 启动板合约地址
        address LaunchPadAdmin;     // 启动板管理员地址
    }
    
    /// @dev 记录ID是否已被使用
    mapping(uint => bool) idIsTaken;
    /// @dev 代币地址到启动板ID的映射
    mapping(address => uint) LaunchpadIdRecord;
    /// @dev 启动板ID到详细信息的映射
    mapping(uint => padDetails) LaunchPadRecord;
    /// @dev 代币地址到启动板地址的映射
    mapping(address => address) TokenToLaunchPadRecord;

    /**
     * @dev 只有项目管理员可以调用的修饰符
     */
    modifier IsAdmin() {
        require(msg.sender == ProjectAdmin, "NOT THE PROJECT ADMIN");
        _;
    }

    /**
     * @dev 只有已验证的启动板管理员可以调用的修饰符
     * @param regId 注册ID
     * @param _padToken 代币地址
     */
    modifier onlyVerifiedAdmin(uint regId, address _padToken) {
        require(idIsTaken[regId] == true, "INVALID ID");
        require(
            LaunchPadRecord[regId].LaunchPadAdmin == msg.sender,
            "NOT REGISTERED ADMIN"
        );
        require(
            LaunchPadRecord[regId].LaunchPadStartTime <= block.timestamp,
            "REGISTRATION NOT OPEN YET"
        );
        require(LaunchpadIdRecord[_padToken] == regId, "TOKEN NOT REGISTERED");
        _;
    }

    /**
     * @dev 构造函数，初始化工厂合约
     * @param admin 项目管理员地址
     * @param _launchPadFees 启动板手续费百分比
     */
    constructor(address admin, uint _launchPadFees) {
        ProjectAdmin = admin;
        launchPadFee = _launchPadFees;
    }

    /**
     * @dev 注册启动板项目
     * @param _launchPadAdmin 启动板管理员地址
     * @param PadToken 要发行的代币地址
     * @param regId 注册ID，必须唯一且不为0
     * @param _startTime 启动板开始时间戳
     * @notice 只有项目管理员可以调用此函数注册启动板项目
     */
    function registerLaunchPads(
        address _launchPadAdmin,
        address PadToken,
        uint regId,
        uint _startTime
    ) public IsAdmin {
        if (regId == 0) revert cannot_Accept_Zero_Value();
        if (_launchPadAdmin == address(0) || PadToken == address(0))
            revert Cannot_Be_Address_Zero();
        if (idIsTaken[regId] == true) revert Id_Already_Taken();
        LaunchpadIdRecord[PadToken] = regId;
        LaunchPadRecord[regId].LaunchPadAdmin = _launchPadAdmin;
        LaunchPadRecord[regId].LaunchPadStartTime = _startTime;
        idIsTaken[regId] = true;
        emit LaunchPadRegistered(PadToken, regId);
    }

    /**
     * @dev 创建启动板合约实例
     * @param regId 注册ID
     * @param _padToken 代币合约地址
     * @param _LaunchPadTSupply 启动板代币供应量
     * @param _preSaleTokenSupply 预售代币供应量
     * @param _PadDuration 启动板持续时间（秒）
     * @param _percentagePresalePriceIncrease 预售价格增长百分比
     * @notice 只有已注册的管理员可以调用，创建具体的启动板合约
     */
    function createLaunchPad(
        uint regId,
        address _padToken,
        uint256 _LaunchPadTSupply,
        uint256 _preSaleTokenSupply,
        uint256 _PadDuration,
        uint _percentagePresalePriceIncrease
    ) public onlyVerifiedAdmin(regId, _padToken) {
        InfinityDaoLaunchPad infinityDaoLaunchPad = new InfinityDaoLaunchPad(
            ProjectAdmin,
            launchPadFee,
            _padToken,
            address(this),
            _LaunchPadTSupply,
            _preSaleTokenSupply,
            _PadDuration,
            msg.sender,
            _percentagePresalePriceIncrease
        );
        uint totalToken = _LaunchPadTSupply + _preSaleTokenSupply;
        bool success = IUSDT(_padToken).transferFrom(
            msg.sender,
            address(infinityDaoLaunchPad),
            totalToken
        );
        require(success, "ERROR TRANSFERING TOKENS");
        launchpads.push(address(infinityDaoLaunchPad));
        LaunchPadRecord[regId].LaunchpadAddress = address(infinityDaoLaunchPad);
        TokenToLaunchPadRecord[_padToken] = address(infinityDaoLaunchPad);
        emit launchpadCreated(
            address(infinityDaoLaunchPad),
            _padToken,
            _PadDuration
        );
    }

    /**
     * @dev 设置启动板手续费
     * @param _amount 新的手续费百分比
     * @notice 只有项目管理员可以调用
     */
    function setLaunchPadFee(uint _amount) public IsAdmin {
        require(_amount != 0, "INVALID PERCENTAGE FEE");
        launchPadFee = _amount;
    }

    /**
     * @dev 获取所有启动板地址
     * @return 启动板地址数组
     */
    function getLaunchPads() public view returns (address[] memory) {
        return launchpads;
    }

    /**
     * @dev 根据代币地址获取对应的启动板地址
     * @param tokenAddress 代币合约地址
     * @return 启动板合约地址
     */
    function getLaunchPadAddress(
        address tokenAddress
    ) public view returns (address) {
        return TokenToLaunchPadRecord[tokenAddress];
    }

    /**
     * @dev 提取合约中的ETH
     * @param _amount 要提取的ETH数量
     * @notice 只有项目管理员可以调用
     */
    function withdrawEth(uint _amount) public IsAdmin {
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "TRANSFER ERROR OCCURED");
    }

    receive() external payable {}
}