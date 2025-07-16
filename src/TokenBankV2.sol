pragma solidity ^0.8.0;

import "./TokenBank.sol";
import "./ERC20.sol";

contract TokenBankV2 is TokenBank, IERC777Recipient {

    // 新增事件：Hook存款
    event HookDeposit(address indexed user, uint256 amount, bytes userData);
    constructor(address _token) TokenBank(_token) {
        // 继承父合约的构造函数
    }
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external override {
        require(msg.sender == address(token), "Only supported token can call this");
        // 确保接收方是本合约
        require(to == address(this), "Invalid recipient");
    }

    function depositWithCallback(uint256 amount, bytes memory userData) public {
        require(amount > 0, "Amount must be greater than 0");
        
        // 检查用户余额
        require(token.balanceOf(msg.sender) >= amount, "Insufficient token balance");
        
        // 调用扩展ERC20的transferWithCallback函数
        // 这将触发tokensReceived Hook
        BaseERC20(address(token)).transferWithCallback(
            msg.sender,    // operator
            msg.sender,    // from
            address(this), // to
            amount,        // amount
            userData,      // userData
            "",            // operatorData
        );
    }
    