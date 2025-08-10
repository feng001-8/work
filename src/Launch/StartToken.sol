pragma solidity 0.8.0;



import "openzeppelin/token/ERC20/ERC20.sol"
import "openzeppelin/access/Ownable.sol"

     
contract MemeToken is ERC20,Ownable{

    constructor(address to,string memory _name,string memory _symbol) ERC20(_name,_symbol){
        // 检查接收地址不为零地址
        require(to != address(0), "MemeToken: invalid recipient");
        // 铸造 1,000,000 枚代币（假设decimals为18）
        _mint(to, 1000000 * 10 ** decimals());
    }



}