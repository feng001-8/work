// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockUSDC - 模拟 USDC 稳定币
 * @dev 用于测试的 ERC20 稳定币合约
 */
contract MockUSDC is ERC20, Ownable {
    uint8 private _decimals;
    
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _decimals = decimals_;
        _transferOwnership(msg.sender);
        _mint(msg.sender, initialSupply);
    }
    
    /**
     * @dev 返回代币精度
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    /**
     * @dev 铸造代币（仅所有者）
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @dev 销毁代币（仅所有者）
     * @param from 销毁地址
     * @param amount 销毁数量
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
    
    /**
     * @dev 批量转账
     * @param recipients 接收地址数组
     * @param amounts 转账数量数组
     */
    function batchTransfer(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external {
        require(recipients.length == amounts.length, "MockUSDC: array length mismatch");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            transfer(recipients[i], amounts[i]);
        }
    }
    
    /**
     * @dev 免费领取代币（用于测试）
     * @param amount 领取数量
     */
    function faucet(uint256 amount) external {
        require(amount <= 10000 * 10**_decimals, "MockUSDC: faucet limit exceeded");
        _mint(msg.sender, amount);
    }
}