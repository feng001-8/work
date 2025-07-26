// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import "openzeppelin/access/Ownable.sol";

contract MyToken is ERC20Permit, Ownable {
    /**
        @notice 构造函数信息
        @param _name 代币名称（对应ERC20）
        @param _symbol 代币符号（对应ERC20）
        @param _initSupply 初始发行量（未包含小数位）
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initSupply
    ) ERC20(_name, _symbol) ERC20Permit(_name) Ownable(msg.sender) {
        // 修正拼写错误：msg.send → msg.sender
        _mint(msg.sender, _initSupply * 10 ** decimals());
    }

    /**
        @notice 仅Owner可铸造新代币
        @param to 接收地址
        @param amount 铸造数量（未包含小数位）
        @dev 检查接收地址非零且数量为正
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "mint to zero address"); // 修正拼写：zore → zero
        require(amount > 0, "mint amount not zero"); // 修正拼写：zore → zero
        // 修正逻辑：应该铸造给to，而非msg.sender
        _mint(to, amount * 10 ** decimals());
    }

    /**
        @notice 销毁调用者持有的代币
        @param amount 销毁数量（未包含小数位）
        @dev 检查销毁数量不超过余额
     */
    // 修正修饰符：owner → onlyOwner（或移除，根据需求）
    function burn(uint256 amount) external {
        require(amount > 0, "Burn amount must be positive");
        uint256 amountWithDecimals = amount * 10 ** decimals();
        require(balanceOf(msg.sender) >= amountWithDecimals, "Insufficient balance");
        _burn(msg.sender, amountWithDecimals);
    }
}