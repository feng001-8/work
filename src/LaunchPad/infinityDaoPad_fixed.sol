// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IUSDT.sol";
import "../lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

/**
 * @title InfinityDaoLaunchPad (Fixed Version)
 * @dev 启动板合约，实现代币发行和预售功能
 * @notice 该合约支持双阶段发行模式：启动板阶段和预售阶段
 * @notice 修复版本解决了原版本中的关键安全问题
 */
contract InfinityDaoLaunchPadFixed is ReentrancyGuard {
    /// @dev 启动板创建事件
    event launchpadCreated(
        address moderator,
        address padtoken,
        uint padDuration
    );
    /// @dev 用户向启动板存入ETH事件
    event DepositedToLaunchPad(address _depositor, uint _ammount);
    /// @dev 用户提取启动板代币事件
    event LaunchPadTokenWithdrawn(address _user, uint _ammount);
    /// @dev 管理员提取启动板代币事件
    event LaunchPadTokenWithdrawnByAdmin(address _user, uint _ammount);
    /// @dev 启动板代币兑换ETH事件
    event launchPadTokenSwappedToEther(
        address _user,
        uint tokenQuantity,
        uint Eth
    );
    /// @dev 管理员提取ETH事件
    event EthWithdrawnByAdmin(address admin, uint amount);
    /// @dev 到期日延长事件
    event ExpirydateExtended(uint time);
    /// @dev 新预售事件
    event newPresale(address user, uint tokenReceived);
    /// @dev 预售流动性清空事件
    event PresaleLiquidityEmptied(address admin, uint presaleTotalSupply);

    /**
     * ======================================================================== *
     * --------------------------- ERRORS ------------------------------------- *
     * ======================================================================== *
     */
    /// @dev 无效转账金额错误
    error invalidTransferAmount();
    /// @dev 启动板已结束，检查预售错误
    error Pad_ended_check_presale();
    /// @dev 启动板已结束错误
    error Pad_ended();
    /// @dev 已经领取过代币错误
    error Already_Claimed_Token();
    /// @dev 未参与启动板错误
    error Didnt_Participate_in_Launchpad();
    /// @dev 启动板仍在进行中错误
    error LaunchPad_Still_In_Progress();
    /// @dev 未找到启动板记录错误
    error no_Launch_Pad_RecordFound();
    /// @dev 金额不能为零错误
    error Amount_Cannot_be_Zero();
    /// @dev 金额超过已领取代币错误
    error Amount_Exceeds_ClaimedTokens();
    /// @dev 金额超过返还代币错误
    error Amount_Exceeds_Returned_Tokens();
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
    /// @dev 预售必须关闭错误
    error Presale_Must_Be_Closed();
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
    address feeReceiver;
    /// @dev 合约监督者地址
    address contractOverseer;
    /// @dev 总手续费
    uint totalFees;
    /// @dev 启动板代币兑换率 (每ETH可获得的代币数量)
    uint256 TokenRateFromPad;
    /// @dev 启动板手续费百分比
    uint launchPadFee;
    /// @dev 是否已支付手续费
    bool hasPaidFees;

    // ======================================================================== 
    // --------------------------- 启动板记录 --------------------------------- 
    // ======================================================================== 
    /// @dev 启动板是否激活
    bool isActive;
    /// @dev 启动板代币合约地址
    address padToken;
    /// @dev 启动板管理员地址
    address padModerator;

    /// @dev 启动板代币总供应量
    uint256 LaunchPadTSupply;
    /// @dev 已领取的启动板代币总量
    uint256 totalPadTokensClaimed;
    /// @dev 启动板筹集的ETH总量
    uint256 EthRaisedByPad;
    /// @dev 启动板持续时间（时间戳）
    uint256 PadDuration;
    /// @dev 从启动板提取的ETH总量
    uint256 EthWithdrawnFromPad;
    /// @dev 启动板参与者地址数组
    address[] launchPadParticipators;
    /// @dev 返还的代币数量
    uint256 returnedTokens;

    // ======================================================================== 
    // --------------------------- 预售记录 ----------------------------------- 
    // ======================================================================== 
    /// @dev 预售是否已关闭
    bool isPresaleClosed;
    /// @dev 预售代币总供应量
    uint256 presaleTotalSupply;
    /// @dev 预售筹集的ETH总量
    uint256 EthRaisedFromPresale;
    /// @dev 预售价格增长百分比
    uint256 percentagePriceIncrease;
    /// @dev 预售参与者地址数组
    address[] presaleParticipants;

    // ======================================================================== 
    // --------------------------- 用户记录 ----------------------------------- 
    // ======================================================================== 
    /// @dev 用户是否已领取启动板代币
    mapping(address => bool) hasClaimedLaunchpadTokens;
    /// @dev 用户向启动板存入的ETH数量
    mapping(address => uint) userEthDepositedToLaunchpad;
    /// @dev 用户拥有的启动板代币数量
    mapping(address => uint) launchPadTokensOwned;

    using SafeMath for uint256;

    /**
     * @dev 构造函数，初始化启动板合约
     * @param _contractOverseer 合约监督者地址
     * @param _launchPadFee 启动板手续费百分比
     * @param _padToken 启动板代币合约地址
     * @param _feeReceiver 手续费接收地址
     * @param _LaunchPadTSupply 启动板代币总供应量
     * @param _preSaleTokenSupply 预售代币供应量
     * @param _PadDuration 启动板持续时间（分钟）
     * @param _moderator 启动板管理员地址
     * @param _percentagePresalePriceIncrease 预售价格增长百分比
     */
    constructor(
        address _contractOverseer,
        uint _launchPadFee,
        address _padToken,
        address _feeReceiver,
        uint256 _LaunchPadTSupply,
        uint256 _preSaleTokenSupply,
        uint256 _PadDuration,
        address _moderator,
        uint _percentagePresalePriceIncrease
    ) {
        createLaunchPad(
            _contractOverseer,
            _launchPadFee,
            _padToken,
            _feeReceiver,
            _LaunchPadTSupply,
            _preSaleTokenSupply,
            _PadDuration,
            _moderator,
            _percentagePresalePriceIncrease
        );
    }

    /**
     * @dev 内部函数，创建启动板
     * @param _contractOverseer 合约监督者地址
     * @param _launchPadFee 启动板手续费百分比
     * @param _padToken 启动板代币合约地址
     * @param _feeReceiver 手续费接收地址
     * @param _LaunchPadTSupply 启动板代币总供应量
     * @param _preSaleTokenSupply 预售代币供应量
     * @param _PadDuration 启动板持续时间（分钟）
     * @param _moderator 启动板管理员地址
     * @param _percentagePresalePriceIncrease 预售价格增长百分比
     */
    function createLaunchPad(
        address _contractOverseer,
        uint _launchPadFee,
        address _padToken,
        address _feeReceiver,
        uint256 _LaunchPadTSupply,
        uint256 _preSaleTokenSupply,
        uint256 _PadDuration,
        address _moderator,
        uint _percentagePresalePriceIncrease
    ) internal {
        require(_padToken != address(0), "Invalid token address");
        require(_LaunchPadTSupply > 0, "Invalid supply");
        require(_PadDuration > 0, "Invalid duration");
        require(_moderator != address(0), "Invalid moderator");
        require(_feeReceiver != address(0), "Invalid fee receiver");
        
        if (_preSaleTokenSupply > 0) {
            require(_percentagePresalePriceIncrease > 0, "PERCENTAGE TOO LOW");
            require(
                _percentagePresalePriceIncrease <= 100,
                "PERCENTAGE TOO HIGH"
            );
        }
        recordPadCreation(
            _contractOverseer,
            _launchPadFee,
            _feeReceiver,
            _padToken,
            _LaunchPadTSupply,
            _moderator,
            _PadDuration,
            _preSaleTokenSupply,
            _percentagePresalePriceIncrease
        );
    }

    /**
     * @dev 用户使用ETH参与启动板投资
     * @notice 用户发送ETH到合约参与代币发行，实现ILAUNCHPAD接口
     */
    function participateWithEth() public payable nonReentrant {
        if (block.timestamp > PadDuration) revert Pad_ended_check_presale();
        if (msg.value == 0) revert invalidTransferAmount();
        if (!isActive) revert Pad_ended();
        
        // 检查是否是新参与者
        if (userEthDepositedToLaunchpad[msg.sender] == 0) {
            launchPadParticipators.push(msg.sender);
        }
        
        EthRaisedByPad += msg.value;
        userEthDepositedToLaunchpad[msg.sender] += msg.value;
        emit DepositedToLaunchPad(msg.sender, msg.value);
    }

    /**
     * @dev 用户提取启动板代币
     * @notice 启动板结束后，参与者可以根据投资比例提取代币
     */
    function WithdrawLaunchPadToken() public nonReentrant {
        if (hasClaimedLaunchpadTokens[msg.sender] == true)
            revert Already_Claimed_Token();
        if (userEthDepositedToLaunchpad[msg.sender] == 0)
            revert Didnt_Participate_in_Launchpad();
        if (block.timestamp < PadDuration) revert LaunchPad_Still_In_Progress();
        
        uint reward = calculateReward();
        hasClaimedLaunchpadTokens[msg.sender] = true;
        totalPadTokensClaimed += reward;
        
        // 更新用户拥有的代币数量
        launchPadTokensOwned[msg.sender] = reward;
        
        bool success = transfer_(IUSDT(padToken), reward, msg.sender);
        require(success, "Token transfer failed");
        
        ChangePadState();
        emit LaunchPadTokenWithdrawn(msg.sender, reward);
    }

    /**
     * @dev 用户将启动板代币兑换为ETH (修复版本)
     * @param _amount 要兑换的代币数量
     * @notice 用户可以将持有的启动板代币兑换回ETH
     * @notice 修复了原版本中的致命逻辑错误
     */
    function swapLaunchPadTokenToEther(uint _amount) public nonReentrant {
        if (hasClaimedLaunchpadTokens[msg.sender] == false)
            revert no_Launch_Pad_RecordFound();
        if (_amount == 0) revert Amount_Cannot_be_Zero();
        if (_amount > launchPadTokensOwned[msg.sender])
            revert Amount_Exceeds_ClaimedTokens();
        
        // 确保启动板已结束且价格已计算
        if (block.timestamp < PadDuration) revert LaunchPad_Still_In_Progress();
        ChangePadState();
        
        // 计算应返还的ETH数量（使用启动板价格，而非预售价格）
        uint ethToReturn = calculateEthFromLaunchPadTokens(_amount);
        
        // 检查合约是否有足够的ETH
        require(address(this).balance >= ethToReturn, "Insufficient contract balance");
        
        // 更新状态变量
        launchPadTokensOwned[msg.sender] = launchPadTokensOwned[msg.sender].sub(_amount);
        EthWithdrawnFromPad = EthWithdrawnFromPad.add(ethToReturn);
        returnedTokens = returnedTokens.add(_amount);
        
        // 转移ETH给用户
        (bool success, ) = payable(msg.sender).call{value: ethToReturn}("");
        require(success, "ETHER TRANSFER FAILED");
        
        emit launchPadTokenSwappedToEther(msg.sender, _amount, ethToReturn);
    }

    /**
     * @dev 计算启动板代币对应的ETH数量（修复版本）
     * @param tokenAmount 代币数量
     * @return ethAmount 对应的ETH数量
     * @notice 使用启动板的实际价格计算，而非预售价格
     */
    function calculateEthFromLaunchPadTokens(uint tokenAmount) internal view returns (uint ethAmount) {
        require(TokenRateFromPad > 0, "Token rate not set");
        // TokenRateFromPad = LaunchPadTSupply * 1 ether / EthRaisedByPad
        // 所以 ethAmount = tokenAmount * 1 ether / TokenRateFromPad
        ethAmount = (tokenAmount * 1 ether) / TokenRateFromPad;
    }

    /**
     * @dev 显示启动板贡献者数量
     * @return contributors 贡献者总数
     */
    function displayNoOfLaunchPadContributors()
        public
        view
        returns (uint contributors)
    {
        contributors = launchPadParticipators.length;
    }

    /**
     * @dev 显示所有启动板贡献者地址
     * @return 贡献者地址数组
     */
    function displayLaunchPadContributors()
        public
        view
        returns (address[] memory)
    {
        return launchPadParticipators;
    }

    /**
     * @dev 管理员提取ETH资金，实现ILAUNCHPAD接口
     * @param _amount 要提取的ETH数量
     * @notice 只有启动板管理员可以调用，启动板结束后提取筹集的资金
     */
    function WithdrawEther(uint _amount) public OnlyModerator nonReentrant {
        if (_amount == 0) revert invalidTransferAmount();
        if (block.timestamp < PadDuration) revert LaunchPad_Still_In_Progress();
        
        ChangePadState();
        
        uint PendingDebit = EthWithdrawnFromPad + totalFees;
        if (_amount > ((EthRaisedByPad + EthRaisedFromPresale) - PendingDebit))
            revert Amount_Exceeds_Balance();
        
        uint paidFee;
        if (totalFees > 0) {
            (bool success, ) = payable(feeReceiver).call{value: totalFees}("");
            require(success, "TRANSFER FAILED");
            paidFee = totalFees;
            totalFees = 0;
        }
        
        EthWithdrawnFromPad = EthWithdrawnFromPad.add(paidFee + _amount);
        payable(msg.sender).transfer(_amount);
        emit EthWithdrawnByAdmin(msg.sender, _amount);
    }

    /**
     * @dev 查看启动板筹集的ETH总量
     * @return Raised 筹集的ETH数量
     */
    function viewEthRaisedFromLaunchPad() public view returns (uint Raised) {
        Raised = EthRaisedByPad;
    }

    /**
     * @dev 查看预售筹集的ETH总量
     * @return Raised 预售筹集的ETH数量
     */
    function viewEthRaisedFromPreSale() public view returns (uint Raised) {
        Raised = EthRaisedFromPresale;
    }

    /**
     * @dev 内部函数，根据代币数量计算对应的ETH数量（预售价格）
     * @param reward 代币数量
     * @return Eth 对应的ETH数量
     * @notice 此函数仅用于预售相关计算
     */
    function calculateEth(uint reward) internal view returns (uint Eth) {
        if (presaleTotalSupply == 0 || EthRaisedFromPresale == 0) return 0;
        Eth = ((EthRaisedFromPresale) * reward) / presaleTotalSupply;
    }

    /**
     * @dev 管理员提取返还的启动板代币
     * @param _amount 要提取的代币数量
     * @notice 只有管理员可以提取用户兑换回ETH后返还的代币
     */
    function withdrawPadToken_Admin(uint _amount) public OnlyModerator nonReentrant {
        if (_amount == 0) revert Amount_Cannot_be_Zero();
        if (_amount > (returnedTokens)) revert Amount_Exceeds_Returned_Tokens();
        
        returnedTokens = returnedTokens.sub(_amount);
        bool success = transfer_(IUSDT(padToken), _amount, msg.sender);
        require(success, "Token transfer failed");
        
        emit LaunchPadTokenWithdrawnByAdmin(msg.sender, _amount);
    }

    /**
     * @dev 延长启动板到期时间
     * @param extraMinutes 延长的分钟数
     * @return success 操作是否成功
     * @notice 只有管理员可以在启动板结束前延长时间
     */
    function extendLaunchPadExpiry(
        uint extraMinutes
    ) public OnlyModerator returns (bool success) {
        if (block.timestamp > PadDuration) revert Pad_ended();
        
        PadDuration = PadDuration.add((extraMinutes * 1 minutes));
        success = true;
        emit ExpirydateExtended(extraMinutes);
    }

    /**
     * @dev 用户参与预售阶段，实现ILAUNCHPAD接口
     * @notice 启动板结束后开启预售，用户可以以优惠价格购买代币
     */
    function participateInPresale() public payable nonReentrant {
        require(block.timestamp > PadDuration, "LAUNCHPAD STILL IN PROGRESS");
        
        ChangePadState();
        
        if (isActive == true) revert Presale_Not_Open_Yet();
        if (presaleTotalSupply == 0) revert No_Presale_Liquidity();
        if (isPresaleClosed == true) revert Presale_Closed();
        if (msg.value == 0) revert invalidTransferAmount();
        
        uint tokenReceived = calculateObtainedToken(msg.value);
        if (tokenReceived > presaleTotalSupply)
            revert Insufficient_Presale_Liquidity();
        
        presaleTotalSupply = presaleTotalSupply.sub(tokenReceived);
        EthRaisedFromPresale = EthRaisedFromPresale.add(msg.value);
        presaleParticipants.push(msg.sender);
        
        bool success = IUSDT(padToken).transfer(msg.sender, tokenReceived);
        require(success, "ERROR TRANSFERING TOKENS");
        
        emit newPresale(msg.sender, tokenReceived);
    }

    /**
     * @dev 管理员提取剩余的预售代币
     * @notice 预售结束后，管理员可以提取未售出的代币
     */
    function withdrawExcessPresaleTokken() public OnlyModerator nonReentrant {
        if (isPresaleClosed == false) revert Presale_Must_Be_Closed();
        
        uint tokensToWithdraw = presaleTotalSupply;
        presaleTotalSupply = 0;
        
        bool status = transfer_(IUSDT(padToken), tokensToWithdraw, msg.sender);
        require(status, "ERROR TRANSFERING TOKENS");
        
        emit PresaleLiquidityEmptied(msg.sender, tokensToWithdraw);
    }

    /**
     * @dev 管理员结束预售
     * @notice 管理员可以手动结束预售阶段
     */
    function endPresale() public OnlyModerator {
        if (isPresaleClosed == true) revert Presale_Closed();
        isPresaleClosed = true;
    }

    /**
     * @dev 查看预售筹集的ETH数量
     * @return Eth 预售筹集的ETH总量
     */
    function viewEthRaisedFromPresale() public view returns (uint Eth) {
        Eth = EthRaisedFromPresale;
    }

    /**
     * @dev 查看预售剩余代币余额
     * @return tokenBalance 预售剩余代币数量
     */
    function viewPresaleTokenBalance() public view returns (uint tokenBalance) {
        tokenBalance = presaleTotalSupply;
    }

    /**
     * @dev 内部函数，计算用户在预售中可获得的代币数量
     * @param value 用户投入的ETH数量
     * @return ammount 可获得的代币数量
     */
    function calculateObtainedToken(
        uint value
    ) internal view returns (uint ammount) {
        require(TokenRateFromPad > 0, "Token rate not calculated yet");
        uint determiner = ((percentagePriceIncrease * 1 ether) / 100) + 1 ether;
        ammount = (value * TokenRateFromPad) / determiner;
    }

    /**
     * @dev 内部函数，改变启动板状态
     * @notice 处理启动板状态转换，计算手续费和代币价格
     */
    function ChangePadState() internal {
        if (isActive == true) {
            isActive = false;
        }
        if (hasPaidFees == false && EthRaisedByPad > 0) {
            uint Fee = ((launchPadFee * EthRaisedByPad) / 100);
            totalFees = Fee;
            hasPaidFees = true;
        }
        if (TokenRateFromPad == 0 && EthRaisedByPad > 0) {
            calculateTokenPrice();
        }
    }

    /**
     * @dev 显示所有预售参与者地址
     * @return 预售参与者地址数组
     */
    function displayPresaleParticipants()
        public
        view
        returns (address[] memory)
    {
        return presaleParticipants;
    }

    /**
     * @dev 显示启动板代币兑换率
     * @return rate 代币兑换率
     */
    function DisplayRateFromLaunchPad() public view returns (uint rate) {
        rate = TokenRateFromPad;
    }

    /**
     * @dev 内部函数，计算代币价格
     * @notice 根据筹集的ETH和代币供应量计算兑换率
     */
    function calculateTokenPrice() internal {
        require(EthRaisedByPad > 0, "No ETH raised");
        uint determiner = 1 ether;
        uint price = ((LaunchPadTSupply * determiner) / EthRaisedByPad);
        TokenRateFromPad = price;
    }

    /**
     * @dev 内部函数，安全转账代币
     * @param _token 代币合约接口
     * @param _ammount 转账数量
     * @param _to 接收地址
     * @return 转账是否成功
     */
    function transfer_(
        IUSDT _token,
        uint _ammount,
        address _to
    ) internal returns (bool) {
        bool Status_ = _token.transfer(_to, uint(_ammount));
        require(Status_, "TRANSFER FAILED");
        return Status_;
    }

    /**
     * @dev 内部函数，计算用户应得的代币奖励
     * @return reward 用户应得的代币数量
     * @notice 根据用户投资比例计算应得代币
     */
    function calculateReward() internal view returns (uint256 reward) {
        uint contribution = userEthDepositedToLaunchpad[msg.sender];
        require(EthRaisedByPad > 0, "No ETH raised");
        reward = ((contribution.mul(LaunchPadTSupply)).div(EthRaisedByPad));
    }

    /**
     * @dev 内部函数，记录启动板创建信息
     * @param _contractOverseer 合约监督者地址
     * @param _launchPadFee 启动板手续费百分比
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
        uint _launchPadFee,
        address _feeReceiver,
        address _padToken,
        uint _LaunchPadTSupply,
        address _moderator,
        uint _PadDuration,
        uint _preSaleTokenSupply,
        uint _percentageIncrease
    ) internal {
        contractOverseer = _contractOverseer;
        launchPadFee = _launchPadFee;
        isActive = true;
        padToken = _padToken;
        LaunchPadTSupply = _LaunchPadTSupply;
        PadDuration = ((_PadDuration * 1 minutes) + block.timestamp);
        padModerator = _moderator;
        presaleTotalSupply = _preSaleTokenSupply;
        percentagePriceIncrease = _percentageIncrease;
        feeReceiver = _feeReceiver;
        emit launchpadCreated(_moderator, _padToken, PadDuration);
    }

    /**
     * @dev 切换某个布尔状态，实现ILAUNCHPAD接口
     * @param _state 要设置的布尔值
     * @return 操作是否成功
     * @notice 用于控制合约的某些开关状态
     */
    function flip(bool _state) external OnlyModerator returns (bool) {
        isActive = _state;
        return true;
    }

    /**
     * @dev 调用flip函数的包装器，实现ILAUNCHPAD接口
     * @notice 提供一个无参数的flip调用方式，切换isActive状态
     */
    function callFlip() external OnlyModerator {
        isActive = !isActive;
    }

    /**
     * @dev 查看用户拥有的启动板代币数量
     * @param user 用户地址
     * @return balance 用户代币余额
     */
    function getUserTokenBalance(address user) public view returns (uint balance) {
        balance = launchPadTokensOwned[user];
    }

    /**
     * @dev 查看用户投入的ETH数量
     * @param user 用户地址
     * @return ethAmount 用户投入的ETH数量
     */
    function getUserEthContribution(address user) public view returns (uint ethAmount) {
        ethAmount = userEthDepositedToLaunchpad[user];
    }

    /**
     * @dev 紧急暂停功能（可选）
     * @notice 管理员可以在紧急情况下暂停合约
     */
    bool public emergencyPaused = false;
    
    modifier whenNotPaused() {
        require(!emergencyPaused, "Contract is paused");
        _;
    }
    
    function emergencyPause() external OnlyModerator {
        emergencyPaused = true;
    }
    
    function emergencyUnpause() external OnlyModerator {
        emergencyPaused = false;
    }

    /**
     * @dev 接收ETH的回退函数
     */
    receive() external payable {
        // 可以选择是否允许直接发送ETH
        revert("Use participateWithEth() or participateInPresale()");
    }
}