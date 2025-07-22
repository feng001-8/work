// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IERC777Recipient {
    /**
     * @dev Called by an {IERC777} token contract whenever tokens are being
     * moved or created into a registered account (`to`). The type of operation
     * is conveyed by `from` being the zero address or not.
     *
     * This call occurs _after_ the token contract's state is updated, so
     * {IERC777-balanceOf}, etc., can be used to query the post-operation state.
     *
     * This function may revert to prevent the operation from being executed.
     */
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external;
}


contract BaseERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        name = "BaseERC20";
        symbol = "ZWG";
        decimals = 18;
        totalSupply = 100000000;
        balances[msg.sender] = totalSupply;
    }

    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.
        return account.code.length > 0;
    }


    function transferWithCallback(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) public  {
    // 权限检查：确保调用者有权限从from地址转账
        if (from != msg.sender) {
             require(allowances[from][msg.sender] >= amount, "insufficient-allowance");
        if (allowances[from][msg.sender] != type(uint256).max) {
            allowances[from][msg.sender] -= amount;
        }
    }
        require(balances[from] >= amount, "insufficient-balance");
        balances[msg.sender] -= amount;
        balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        if (isContract(to)) {
            IERC777Recipient(to).tokensReceived(operator, from, to, amount, userData, operatorData);
        }
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value, "insufficient-balance");
        
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(balances[_from] >= _value, "insufficient-balance");
        
        if (_from != msg.sender && allowances[_from][msg.sender] != type(uint256).max) {
            require(allowances[_from][msg.sender] >= _value, "insufficient-allowance");
            allowances[_from][msg.sender] -= _value;
        }
        
        balances[_from] -= _value;
        balances[_to] += _value;
        
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowances[_owner][_spender];
    }
}