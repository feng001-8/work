
pragma solidity ^0.8.0;

interface IBank {
    function deposit() external payable;
    function withdraw() external;
    function balances(address user) external view returns (uint256);
    function arr(uint256 index) external view returns (address);
}