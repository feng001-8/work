pragma solidity ^0.8.0;

contract FunctionSelector {
    uint256 private storedValue;

    function getValue() public view returns (uint) {
        return storedValue;
    }

    function setValue(uint value) public {
        storedValue = value;
    }
/// 补充完整getFunctionSelector1函数，返回getValue函数的签名
    function getFunctionSelector1() public pure returns (bytes4) {
        //
        return bytes4(keccak256("getValue()"));
    }
///补充完整getFunctionSelector2函数，返回setValue函数的签名
    function getFunctionSelector2() public pure returns (bytes4) {
        //
        return bytes4(keccak256("setValue(uint256)"));
    }
}
