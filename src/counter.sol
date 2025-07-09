pragma solidity ^0.8.0;

contract Counter {
    uint256 public counter;
    function get() public view returns (uint256) {
        return counter;
    }
    function add(uint256 x) public {
        counter += x;
    }
}