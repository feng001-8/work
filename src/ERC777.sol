// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ERC777 Token Implementation
 * @dev Implementation of the ERC777 token standard with ERC20 compatibility
 * Based on OpenZeppelin's ERC777 implementation
 */

// ERC777 接口
interface IERC777 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    // 定义代币的最小可分割单位（粒度）granularity
    function granularity() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    
    function send(address recipient, uint256 amount, bytes calldata data) external;
    function burn(uint256 amount, bytes calldata data) external;
    // 检查某个地址是否是代币持有者的操作员 （操作员就是代币持有者本人）（操作员被持有者明确授权）
    function isOperatorFor(address operator, address tokenHolder) external view returns (bool);
    // 授权某个地址作为自己的操作员
    function authorizeOperator(address operator) external;
    // 撤销某个地址的操作员权限
    function revokeOperator(address operator) external;
    // 返回默认操作员列表
    function defaultOperators() external view returns (address[] memory);
    //操作员代表代币持有者发送代币
    function operatorSend(
        address sender,
        address recipient,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;
    // 操作员代表代币持有者销毁代币
    function operatorBurn(
        address account,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;
    
    event Sent(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );
    event Minted(address indexed operator, address indexed to, uint256 amount, bytes data, bytes operatorData);
    event Burned(address indexed operator, address indexed from, uint256 amount, bytes data, bytes operatorData);
    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
    event RevokedOperator(address indexed operator, address indexed tokenHolder);
}

// ERC777 发送钩子接口
interface IERC777Sender {
    function tokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external;
}

// ERC777 接收钩子接口
interface IERC777Recipient {
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external;
}

// ERC20 接口（向后兼容）
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// ERC1820 注册表接口（用于钩子发现）
interface IERC1820Registry {
    function setInterfaceImplementer(address account, bytes32 interfaceHash, address implementer) external;
    function getInterfaceImplementer(address account, bytes32 interfaceHash) external view returns (address);
}

contract ERC777 is IERC777, IERC20 {
    // ERC1820 注册表地址
    IERC1820Registry private constant _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    
    // 接口哈希
    bytes32 private constant _TOKENS_SENDER_INTERFACE_HASH = keccak256("ERC777TokensSender");
    bytes32 private constant _TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");
    
    // 代币基本信息
    string private _name;
    string private _symbol;
    uint256 private _granularity;
    uint256 private _totalSupply;
    
    // 余额和授权映射
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // 操作员映射
    mapping(address => mapping(address => bool)) private _operators;
    address[] private _defaultOperators;
    mapping(address => mapping(address => bool)) private _revokedDefaultOperators;
    
    /**
     * @dev 构造函数
     * @param name_ 代币名称
     * @param symbol_ 代币符号
     * @param defaultOperators_ 默认操作员列表
     * @param totalSupply_ 总供应量
     * @param holder 初始持有者
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address[] memory defaultOperators_,
        uint256 totalSupply_,
        address holder
    ) {
        _name = name_;
        _symbol = symbol_;
        _granularity = 1;
        _defaultOperators = defaultOperators_;
        
        // 注册ERC777和ERC20接口
        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("ERC777Token"), address(this));
        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("ERC20Token"), address(this));
        
        // 铸造初始供应量
        _mint(holder, totalSupply_, "", "");
    }
    
    // ========== ERC777 基本信息函数 ==========
    
    function name() public view override returns (string memory) {
        return _name;
    }
    
    function symbol() public view override returns (string memory) {
        return _symbol;
    }
    
    function decimals() public pure returns (uint8) {
        return 18;
    }
    
    function granularity() public view override returns (uint256) {
        return _granularity;
    }
    
    function totalSupply() public view override(IERC777, IERC20) returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view override(IERC777, IERC20) returns (uint256) {
        return _balances[account];
    }
    
    // ========== ERC777 发送函数 ==========
    
    function send(address recipient, uint256 amount, bytes memory data) public override {
        _send(msg.sender, recipient, amount, data, "", true);
    }
    
    function operatorSend(
        address sender,
        address recipient,
        uint256 amount,
        bytes memory data,
        bytes memory operatorData
    ) public override {
        require(isOperatorFor(msg.sender, sender), "ERC777: caller is not an operator for holder");
        _send(sender, recipient, amount, data, operatorData, true);
    }
    
    // ========== ERC777 销毁函数 ==========
    
    function burn(uint256 amount, bytes memory data) public override {
        _burn(msg.sender, amount, data, "");
    }
    
    function operatorBurn(
        address account,
        uint256 amount,
        bytes memory data,
        bytes memory operatorData
    ) public override {
        require(isOperatorFor(msg.sender, account), "ERC777: caller is not an operator for holder");
        _burn(account, amount, data, operatorData);
    }
    
    // ========== ERC777 操作员函数 ==========
    
    function defaultOperators() public view override returns (address[] memory) {
        return _defaultOperators;
    }
    
    function isOperatorFor(address operator, address tokenHolder) public view override returns (bool) {
        return operator == tokenHolder ||
               (_defaultOperators.length > 0 && _isDefaultOperator(operator) && !_revokedDefaultOperators[tokenHolder][operator]) ||
               _operators[tokenHolder][operator];
    }
    
    function authorizeOperator(address operator) public override {
        require(msg.sender != operator, "ERC777: authorizing self as operator");
        
        if (_defaultOperators.length > 0 && _isDefaultOperator(operator)) {
            delete _revokedDefaultOperators[msg.sender][operator];
        } else {
            _operators[msg.sender][operator] = true;
        }
        
        emit AuthorizedOperator(operator, msg.sender);
    }
    
    function revokeOperator(address operator) public override {
        require(operator != msg.sender, "ERC777: revoking self as operator");
        
        if (_defaultOperators.length > 0 && _isDefaultOperator(operator)) {
            _revokedDefaultOperators[msg.sender][operator] = true;
        } else {
            delete _operators[msg.sender][operator];
        }
        
        emit RevokedOperator(operator, msg.sender);
    }
    
    // ========== ERC20 兼容函数 ==========
    
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _send(msg.sender, recipient, amount, "", "", false);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC777: transfer amount exceeds allowance");
        
        _send(sender, recipient, amount, "", "", false);
        _approve(sender, msg.sender, currentAllowance - amount);
        
        return true;
    }
    
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    // ========== 内部函数 ==========
    
    function _send(
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    ) internal {
        require(from != address(0), "ERC777: send from the zero address");
        require(to != address(0), "ERC777: send to the zero address");
        
        address operator = msg.sender;
        
        // 调用发送钩子
        _callTokensToSend(operator, from, to, amount, userData, operatorData);
        
        // 执行转账
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC777: transfer amount exceeds balance");
        _balances[from] = fromBalance - amount;
        _balances[to] += amount;
        
        // 调用接收钩子
        _callTokensReceived(operator, from, to, amount, userData, operatorData, requireReceptionAck);
        
        emit Sent(operator, from, to, amount, userData, operatorData);
        emit Transfer(from, to, amount);
    }
    
    function _mint(
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) internal {
        require(to != address(0), "ERC777: mint to the zero address");
        
        address operator = msg.sender;
        
        // 更新总供应量和余额
        _totalSupply += amount;
        _balances[to] += amount;
        
        // 调用接收钩子
        _callTokensReceived(operator, address(0), to, amount, userData, operatorData, true);
        
        emit Minted(operator, to, amount, userData, operatorData);
        emit Transfer(address(0), to, amount);
    }
    
    function _burn(
        address from,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) internal {
        require(from != address(0), "ERC777: burn from the zero address");
        
        address operator = msg.sender;
        
        // 调用发送钩子
        _callTokensToSend(operator, from, address(0), amount, userData, operatorData);
        
        // 执行销毁
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC777: burn amount exceeds balance");
        _balances[from] = fromBalance - amount;
        _totalSupply -= amount;
        
        emit Burned(operator, from, amount, userData, operatorData);
        emit Transfer(from, address(0), amount);
    }
    
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC777: approve from the zero address");
        require(spender != address(0), "ERC777: approve to the zero address");
        
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function _callTokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) private {
        address implementer = _ERC1820_REGISTRY.getInterfaceImplementer(from, _TOKENS_SENDER_INTERFACE_HASH);
        if (implementer != address(0)) {
            IERC777Sender(implementer).tokensToSend(operator, from, to, amount, userData, operatorData);
        }
    }
    
    function _callTokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    ) private {
        address implementer = _ERC1820_REGISTRY.getInterfaceImplementer(to, _TOKENS_RECIPIENT_INTERFACE_HASH);
        if (implementer != address(0)) {
            IERC777Recipient(implementer).tokensReceived(operator, from, to, amount, userData, operatorData);
        } else if (requireReceptionAck) {
            require(!_isContract(to), "ERC777: token recipient contract has no implementer for ERC777TokensRecipient");
        }
    }
    
    function _isDefaultOperator(address operator) private view returns (bool) {
        for (uint256 i = 0; i < _defaultOperators.length; i++) {
            if (_defaultOperators[i] == operator) {
                return true;
            }
        }
        return false;
    }
    
    function _isContract(address account) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
    
    // ========== 管理员函数 ==========
    
    /**
     * @dev 铸造新代币（仅限合约所有者）
     */
    function mint(address to, uint256 amount, bytes memory userData, bytes memory operatorData) public {
        // 在实际应用中，这里应该添加访问控制
        _mint(to, amount, userData, operatorData);
    }
}