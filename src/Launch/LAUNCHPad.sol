// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ILAUNCHPAD.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title LAUNCHPad
 * @dev 启动板合约，实现代币发行和预售功能
 * @notice 该合约支持双阶段发行模式：启动板阶段和预售阶段
 */
contract LAUNCHPad is ILAUNCHPAD, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /**
     * ======================================================================== *
     * --------------------------- EVENTS ------------------------------------ *
     * ======================================================================== *
     */
    /// @dev 启动板创建事件
    event LaunchpadCreated(address moderator, address padtoken, uint padDuration);
    /// @dev 用户向启动板存入ETH事件
    event DepositedToLaunchPad(address _depositor, uint _amount);
    /// @dev 用户提取启动板代币事件
    event LaunchPadTokenWithdrawn(address _user, uint _amount);
    /// @dev 启动板代币兑换ETH事件
    event LaunchPadTokenSwappedToEther(address _user, uint tokenQuantity, uint ethAmount);
    /// @dev 管理员提取ETH事件
    event EthWithdrawnByAdmin(address admin, uint amount);
    /// @dev 新预售事件
    event NewPresale(address user, uint ethAmount, uint tokenReceived);
    /// @dev 预售结束事件
    event PresaleEnded(uint totalEthRaised, uint participantCount);

    /**
     * ======================================================================== *
     * --------------------------- ERRORS ------------------------------------- *
     * ======================================================================== *
     */
    /// @dev 无效转账金额错误
    error InvalidTransferAmount();
    /// @dev 启动板已结束，检查预售错误
    error Pad_Ended_Check_Presale();
    /// @dev 启动板已结束错误
    error Pad_Ended();
    /// @dev 已经领取过代币错误
    error Already_Claimed_Token();
    /// @dev 未参与启动板错误
    error Didnt_Participate_In_Launchpad();
    /// @dev 启动板仍在进行中错误
    error LaunchPad_Still_In_Progress();
    /// @dev 未找到启动板记录错误
    error No_Launch_Pad_Record_Found();
    /// @dev 金额不能为零错误
    error Amount_Cannot_Be_Zero();
    /// @dev 金额超过已领取代币错误
    error Amount_Exceeds_Claimed_Tokens();
    /// @dev 金额超过余额错误
    error Amount_Exceeds_Balance();
    /// @dev 预售尚未开放错误
    error Presale_Not_Open_Yet();
    /// @dev 无预售流动性错误
    error No_Presale_Liquidity();
    /// @dev 预售已关闭错误
    error Presale_Closed();
    /// @dev 预售流动性不足错误
    error Insufficient_Presale_Liquidity();
    /// @dev 代币余额不足错误
    error Insufficient_Token_Balance();


    /**
     * @dev 只有启动板管理员可以调用的修饰符
     */
    modifier OnlyModerator() {
        require(msg.sender == padModerator, "NOT LaunchPad Moderator");
        _;
    }

    // ======================================================================== 
    // --------------------------- 通用记录 ----------------------------------- 
    // ======================================================================== 
    /// @dev 手续费接收地址
    address public feeReceiver;
    /// @dev 合约监督者地址
    address public contractOverseer;
    /// @dev 总手续费
    uint256 public totalFees;
    /// @dev 启动板代币兑换率 (每ETH可获得的代币数量)
    uint256 public TokenRateFromPad;
    /// @dev 启动板手续费百分比
    uint256 public launchPadFee;
    /// @dev 是否已支付手续费
    bool public hasPaidFees;


    // ======================================================================== 
    // --------------------------- 启动板记录 --------------------------------- 
    // ======================================================================== 
    /// @dev 启动板是否激活
    bool public isActive;
    /// @dev 启动板代币合约地址
    address public padToken;
    /// @dev 启动板管理员地址
    address public padModerator;
    /// @dev 启动板代币总供应量
    uint256 public LaunchPadTSupply;
    /// @dev 已领取的启动板代币总量
    uint256 public totalPadTokensClaimed;
    /// @dev 启动板筹集的ETH总量
    uint256 public EthRaisedByPad;
    /// @dev 启动板持续时间（时间戳）
    uint256 public PadDuration;
    /// @dev 从启动板提取的ETH总量
    uint256 public EthWithdrawnFromPad;
    /// @dev 启动板参与者地址数组
    address[] public launchPadParticipators;
    /// @dev 返还的代币数量
    uint256 public returnedTokens;

    // ======================================================================== 
    // --------------------------- 预售记录 ----------------------------------- 
    // ======================================================================== 
    /// @dev 预售是否已关闭
    bool public isPresaleClosed;
    /// @dev 预售代币总供应量
    uint256 public presaleTotalSupply;
    /// @dev 预售筹集的ETH总量
    uint256 public EthRaisedFromPresale;
    /// @dev 预售价格增长百分比
    uint256 public percentagePriceIncrease;
    /// @dev 预售参与者地址数组
    address[] public presaleParticipants;



    // ======================================================================== 
    // --------------------------- 用户记录 ----------------------------------- 
    // ======================================================================== 
    /// @dev 用户是否已领取启动板代币
    mapping(address => bool) public hasClaimedLaunchpadTokens;
    /// @dev 用户向启动板存入的ETH数量
    mapping(address => uint256) public userEthDepositedToLaunchpad;
    /// @dev 用户拥有的启动板代币数量
    mapping(address => uint256) public launchPadTokensOwned;



    /**
     * @dev 构造函数，初始化启动板合约
     * @param _contractOverseer 合约监督者地址
     * @param _launchPadFee 启动板手续费百分比
     * @param _feeReceiver 手续费接收地址
     * @param _padAdmin 启动板管理员地址
     * @param _padToken 启动板代币合约地址
     * @param _padDuration 启动板持续时间（分钟）
     * @param _LaunchPadTSupply 启动板代币总供应量
     * @param _preSaleTokenSupply 预售代币供应量
     * @param _percentagePresalePriceIncrease 预售价格增长百分比
     */
    constructor(
        address _contractOverseer,
        uint256 _launchPadFee,
        address _feeReceiver,
        address _padAdmin,
        address _padToken,
        uint256 _padDuration,
        uint256 _LaunchPadTSupply,
        uint256 _preSaleTokenSupply,
        uint256 _percentagePresalePriceIncrease
    ) {
        createLaunchPad(
            _contractOverseer,
            _launchPadFee,
            _feeReceiver,
            _padAdmin,
            _padToken,
            _padDuration,
            _LaunchPadTSupply,
            _preSaleTokenSupply,
            _percentagePresalePriceIncrease
        );
    }

    /**
     * @dev 创建启动板的内部函数
     * @param contractOverseer 合约监督者地址
     * @param launchPadFee 启动板手续费百分比
     * @param feeReceiver 手续费接收地址
     * @param padAdmin 启动板管理员地址
     * @param padToken 启动板代币合约地址
     * @param padDuration 启动板持续时间（分钟）
     * @param LaunchPadTSupply 启动板代币总供应量
     * @param preSaleTokenSupply 预售代币供应量
     * @param percentagePresalePriceIncrease 预售价格增长百分比
     */
    function createLaunchPad(
        address contractOverseer,
        uint256 launchPadFee,
        address feeReceiver,
        address padAdmin,
        address padToken,
        uint256 padDuration,
        uint256 LaunchPadTSupply,
        uint256 preSaleTokenSupply,
        uint256 percentagePresalePriceIncrease
    ) internal {
        // 参数验证
        require(contractOverseer != address(0), "Invalid overseer address");
        require(feeReceiver != address(0), "Invalid fee receiver address");
        require(padAdmin != address(0), "Invalid admin address");
        require(padToken != address(0), "Invalid token address");
        require(launchPadFee <= 100, "Fee cannot exceed 100%");
        require(padDuration > 0, "Duration must be positive");
        require(LaunchPadTSupply > 0, "Supply must be positive");
        require(preSaleTokenSupply > 0, "Presale supply must be positive");
        require(percentagePresalePriceIncrease > 0, "Price increase must be positive");
        
        // 记录创建信息
        recordPadCreation(
            contractOverseer,
            launchPadFee,
            feeReceiver,
            padAdmin,
            padToken,
            padDuration,
            LaunchPadTSupply,
            preSaleTokenSupply,
            percentagePresalePriceIncrease
        );
    }

        /**
     * @dev 内部函数，记录启动板创建信息
     * @param _contractOverseer 合约监督者地址
     * @param _launchPadFee 手续费百分比
     * @param _feeReceiver 手续费接收地址
     * @param _padToken 启动板代币合约地址
     * @param _LaunchPadTSupply 启动板代币总供应量
     * @param _moderator 启动板管理员地址
     * @param _PadDuration 启动板持续时间（分钟）
     * @param _preSaleTokenSupply 预售代币供应量
     * @param _percentageIncrease 预售价格增长百分比
     * @notice 初始化启动板的所有参数和状态
     */
    function recordPadCreation(
        address _contractOverseer,
        uint256 _launchPadFee,
        address _feeReceiver,
        address _padAdmin,
        address _padToken,
        uint256 _padDuration,
        uint256 _LaunchPadTSupply,
        uint256 _preSaleTokenSupply,
        uint256 _percentageIncrease
    ) internal {
        // 初始化通用记录
        contractOverseer = _contractOverseer;
        launchPadFee = _launchPadFee;
        feeReceiver = _feeReceiver;
        totalFees = 0;
        TokenRateFromPad = 0; // 将在第一次参与时计算
        hasPaidFees = false;

        // 初始化启动板记录
        padModerator = _padAdmin;
        padToken = _padToken;
        PadDuration = ((_padDuration * 1 minutes) + block.timestamp);
        LaunchPadTSupply = _LaunchPadTSupply;
        totalPadTokensClaimed = 0;
        EthRaisedByPad = 0;
        EthWithdrawnFromPad = 0;
        returnedTokens = 0;
        isActive = true;

        // 初始化预售记录
        presaleTotalSupply = _preSaleTokenSupply;
        percentagePriceIncrease = _percentageIncrease;
        isPresaleClosed = false;
        EthRaisedFromPresale = 0;

        // 发射启动板创建事件
        emit LaunchpadCreated(
            _padToken,
            _padAdmin,
            _LaunchPadTSupply,
            _preSaleTokenSupply,
            PadDuration,
            _percentageIncrease
        );
    }


    /**
     * @dev 用户使用ETH参与启动板投资
     * @notice 用户发送ETH到合约参与代币发行，按ETH贡献比例分配代币
     */
    function participateWithEth() external payable nonReentrant {
        // 检查启动板是否仍在进行中
        require(block.timestamp <= PadDuration, "LaunchPad_Still_In_Progress");
        require(isActive, "LaunchPad is not active");
        require(msg.value > 0, "Amount_Cannot_Be_Zero");
        
        // 如果是新参与者，添加到参与者列表
        if (userEthDepositedToLaunchpad[msg.sender] == 0) {
            launchPadParticipators.push(msg.sender);
        }
        
        // 更新用户和总体投资记录
        EthRaisedByPad = EthRaisedByPad.add(msg.value);
        userEthDepositedToLaunchpad[msg.sender] = userEthDepositedToLaunchpad[msg.sender].add(msg.value);
        
        // 计算代币汇率（如果是第一次参与）
        if (TokenRateFromPad == 0 && EthRaisedByPad > 0) {
            TokenRateFromPad = LaunchPadTSupply.mul(1e18).div(EthRaisedByPad);
        }
        
        emit DepositedToLaunchPad(msg.sender, msg.value);
    }

    /**
     * @dev 用户提取启动板代币
     * @notice 启动板结束后，参与者可以根据投资比例提取代币
     */
    function WithdrawLaunchPadToken() external nonReentrant {
        require(block.timestamp > PadDuration, "Pad_Ended");
        require(!hasClaimedLaunchpadTokens[msg.sender], "Already_Claimed_Token");
        require(userEthDepositedToLaunchpad[msg.sender] > 0, "Didnt_Participate_In_Launchpad");
        require(EthRaisedByPad > 0, "No_Launch_Pad_Record_Found");
        
        // 计算用户应得的代币数量（按ETH贡献比例）
        uint256 userTokenAmount = calculateReward(msg.sender);
        require(userTokenAmount > 0, "Amount_Cannot_Be_Zero");
        
        // 标记用户已领取
        hasClaimedLaunchpadTokens[msg.sender] = true;
        
        // 更新已领取代币总量
        totalPadTokensClaimed = totalPadTokensClaimed.add(userTokenAmount);
        
        // 记录用户拥有的代币数量
        launchPadTokensOwned[msg.sender] = userTokenAmount;
        
        // 转账代币给用户
        IERC20(padToken).safeTransfer(msg.sender, userTokenAmount);
        
        emit LaunchPadTokenWithdrawn(msg.sender, userTokenAmount);
    }



    /**
     * @dev 用户将启动板代币兑换为ETH
     * @param _amount 要兑换的代币数量
     * @notice 用户可以将持有的启动板代币兑换回ETH，支持回购功能
     */
    function swapTokenToETH(uint256 _amount) external nonReentrant {
        require(hasClaimedLaunchpadTokens[msg.sender], "No_Launch_Pad_Record_Found");
        require(_amount > 0, "Amount_Cannot_Be_Zero");
        require(_amount <= launchPadTokensOwned[msg.sender], "Amount_Exceeds_Balance");
        require(address(this).balance > 0, "Insufficient contract balance");
        
        // 计算应返还的ETH数量（使用正确的启动板价格）
        uint256 ethAmount = calculateEthFromLaunchPadTokens(_amount);
        require(ethAmount > 0, "Amount_Cannot_Be_Zero");
        require(address(this).balance >= ethAmount, "Insufficient contract balance");
        
        // 更新用户代币余额（直接从映射扣除，无需transferFrom）
        launchPadTokensOwned[msg.sender] = launchPadTokensOwned[msg.sender].sub(_amount);
        
        // 更新合约统计数据
        EthWithdrawnFromPad = EthWithdrawnFromPad.add(ethAmount);
        returnedTokens = returnedTokens.add(_amount);
        
        // 转账ETH给用户
        (bool success, ) = payable(msg.sender).call{value: ethAmount}("");
        require(success, "ETH transfer failed");
        
        emit LaunchPadTokenSwappedToEther(msg.sender, _amount, ethAmount);
    }

    /**
     * @dev 计算用户应得的启动板代币奖励
     * @param user 用户地址
     * @return reward 用户应得的代币数量
     * @notice 根据用户ETH投资比例计算应得代币
     */
    function calculateReward(address user) internal view returns (uint256 reward) {
        uint256 contribution = userEthDepositedToLaunchpad[user];
        require(EthRaisedByPad > 0, "No ETH raised");
        reward = contribution.mul(LaunchPadTSupply).div(EthRaisedByPad);
    }

    /**
     * @dev 根据启动板代币数量计算对应的ETH数量（用于回购）
     * @param tokenAmount 代币数量
     * @return ethAmount 对应的ETH数量
     * @notice 使用启动板的价格比率计算ETH价值
     */
    function calculateEthFromLaunchPadTokens(uint256 tokenAmount) internal view returns (uint256 ethAmount) {
        require(LaunchPadTSupply > 0, "Invalid LaunchPad supply");
        require(EthRaisedByPad > 0, "No ETH raised");
        ethAmount = tokenAmount.mul(EthRaisedByPad).div(LaunchPadTSupply);
    }

    /**
     * @dev 根据预售代币数量计算需要的ETH数量
     * @param tokenAmount 预售代币数量
     * @return ethAmount 需要的ETH数量
     * @notice 基于动态定价机制计算预售价格
     */
    function calculatePresaleEthCost(uint256 tokenAmount) internal view returns (uint256 ethAmount) {
        require(presaleTotalSupply > 0, "Invalid presale supply");
        require(percentagePriceIncrease > 0, "Invalid price increase");
        
        // 基础价格：启动板价格 * (1 + 百分比增长)
        uint256 basePrice = EthRaisedByPad.mul(100 + percentagePriceIncrease).div(100).div(LaunchPadTSupply);
        ethAmount = tokenAmount.mul(basePrice);
    }

    /**
     * @dev 根据ETH数量计算可获得的预售代币数量
     * @param ethAmount ETH数量
     * @return tokenAmount 可获得的代币数量
     */
    function calculateObtainedToken(uint256 ethAmount) internal view returns (uint256 tokenAmount) {
        require(percentagePriceIncrease > 0, "Invalid price increase");
        require(LaunchPadTSupply > 0 && EthRaisedByPad > 0, "Invalid LaunchPad data");
        
        // 基础价格：启动板价格 * (1 + 百分比增长)
        uint256 basePrice = EthRaisedByPad.mul(100 + percentagePriceIncrease).div(100).div(LaunchPadTSupply);
        tokenAmount = ethAmount.div(basePrice);
    }

    // ======================================================================== 
    // --------------------------- 预售阶段函数 ------------------------------- 
    // ======================================================================== 

    /**
     * @dev 用户参与预售
     * @notice 启动板结束后自动开启预售，用户可直接购买代币
     */
    function participateInPresale() external payable nonReentrant {
        require(block.timestamp > PadDuration, "Presale_Not_Open_Yet");
        require(!isPresaleClosed, "Presale_Closed");
        require(msg.value > 0, "Amount_Cannot_Be_Zero");
        require(EthRaisedByPad > 0, "No_Presale_Liquidity");
        
        // 计算可获得的代币数量
        uint256 tokenAmount = calculateObtainedToken(msg.value);
        require(tokenAmount > 0, "Amount_Cannot_Be_Zero");
        require(tokenAmount <= presaleTotalSupply, "Insufficient_Presale_Liquidity");
        
        // 检查合约是否有足够的代币
        require(IERC20(padToken).balanceOf(address(this)) >= tokenAmount, "Insufficient_Token_Balance");
        
        // 如果是新参与者，添加到预售参与者列表
        bool isNewParticipant = true;
        for (uint256 i = 0; i < presaleParticipants.length; i++) {
            if (presaleParticipants[i] == msg.sender) {
                isNewParticipant = false;
                break;
            }
        }
        if (isNewParticipant) {
            presaleParticipants.push(msg.sender);
        }
        
        // 更新预售统计数据
        EthRaisedFromPresale = EthRaisedFromPresale.add(msg.value);
        presaleTotalSupply = presaleTotalSupply.sub(tokenAmount);
        
        // 直接转账代币给用户（即时交付）
        IERC20(padToken).safeTransfer(msg.sender, tokenAmount);
        
        emit NewPresale(msg.sender, msg.value, tokenAmount);
        
        // 如果预售代币售完，关闭预售
        if (presaleTotalSupply == 0) {
            isPresaleClosed = true;
            emit PresaleEnded(EthRaisedFromPresale, presaleParticipants.length);
        }
    }

    // ======================================================================== 
    // --------------------------- 管理员函数 --------------------------------- 
    // ======================================================================== 

    /**
     * @dev 管理员提取合约中的ETH
     * @param amount 提取数量
     * @notice 只有合约监督者可以提取ETH，用于费用分配
     */
    function WithdrawEther(uint256 amount) external OnlyModerator nonReentrant {
        require(amount > 0, "Amount_Cannot_Be_Zero");
        require(address(this).balance >= amount, "Insufficient contract balance");
        
        // 计算并扣除平台费用
        if (!hasPaidFees && EthRaisedByPad > 0) {
            uint256 fee = EthRaisedByPad.mul(launchPadFee).div(100);
            totalFees = totalFees.add(fee);
            hasPaidFees = true;
            
            // 转账费用给费用接收者
            (bool feeSuccess, ) = payable(feeReceiver).call{value: fee}("");
            require(feeSuccess, "Fee transfer failed");
            
            emit EthWithdrawnByAdmin(feeReceiver, fee);
        }
        
        // 转账剩余ETH给管理员
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");
        
        emit EthWithdrawnByAdmin(msg.sender, amount);
    }

    // ======================================================================== 
    // --------------------------- 查询函数 ----------------------------------- 
    // ======================================================================== 

    /**
     * @dev 查询用户的启动板代币余额
     * @param user 用户地址
     * @return balance 用户代币余额
     */
    function getUserTokenBalance(address user) external view returns (uint256 balance) {
        return launchPadTokensOwned[user];
    }

    /**
     * @dev 查询用户的ETH投资金额
     * @param user 用户地址
     * @return amount 用户投资的ETH数量
     */
    function getUserEthContribution(address user) external view returns (uint256 amount) {
        return userEthDepositedToLaunchpad[user];
    }

    /**
     * @dev 查询启动板基本信息
     * @return 启动板的各项基本数据
     */
    function getLaunchPadInfo() external view returns (
        address tokenAddress,
        uint256 totalSupply,
        uint256 ethRaised,
        uint256 endTime,
        bool active,
        uint256 participantCount
    ) {
        return (
            padToken,
            LaunchPadTSupply,
            EthRaisedByPad,
            PadDuration,
            isActive,
            launchPadParticipators.length
        );
    }

    /**
     * @dev 查询预售基本信息
     * @return 预售的各项基本数据
     */
    function getPresaleInfo() external view returns (
        uint256 remainingSupply,
        uint256 ethRaised,
        uint256 priceIncrease,
        bool closed,
        uint256 participantCount
    ) {
        return (
            presaleTotalSupply,
            EthRaisedFromPresale,
            percentagePriceIncrease,
            isPresaleClosed,
            presaleParticipants.length
        );
    }

    // ======================================================================== 
    // --------------------------- 接收函数 ----------------------------------- 
    // ======================================================================== 

    /**
     * @dev 接收ETH的回退函数
     * @notice 直接发送ETH到合约将触发participateWithEth
     */
    receive() external payable {
        if (block.timestamp <= PadDuration && isActive) {
            // 启动板阶段
            participateWithEth();
        } else if (block.timestamp > PadDuration && !isPresaleClosed) {
            // 预售阶段
            participateInPresale();
        } else {
            revert("No active phase");
        }
    }

    /**
     * @dev 回退函数
     */
    fallback() external payable {
         revert("Function not found");
     }

    // ======================================================================== 
    // --------------------------- 接口实现函数 ------------------------------- 
    // ======================================================================== 

    /**
     * @dev 实现ILAUNCHPAD接口的flip函数
     * @notice 切换启动板状态的功能函数
     */
    function flip() external OnlyModerator {
        isActive = !isActive;
    }

    /**
     * @dev 实现ILAUNCHPAD接口的callFlip函数
     * @notice 调用flip函数的包装器
     */
    function callFlip() external OnlyModerator {
        flip();
    }
}