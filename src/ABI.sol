// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* abi.decode(bytes memory encodedData, (...)) returns (...)： ABI 
- 对提供的数据进行解码。类型在括号中作为第二个参数给出。 示例： (uint a, uint[2] memory b, bytes memory c) = abi.decode(data, (uint, uint[2], bytes))

abi.encode(...) returns (bytes memory)： ABI 
- 对给定的参数进行编码。

abi.encodePacked(...) returns (bytes memory)： 
对给定的参数执行 紧密打包。 请注意，这种编码可能是不明确的!

abi.encodeWithSelector(bytes4 selector, ...) returns (bytes memory)： 
ABI - 对给定参数进行编码， 并以给定的函数选择器作为起始的 4 字节数据一起返回

abi.encodeCall(function functionPointer, (...)) returns (bytes memory)： 
对 functionPointer 的调用进行ABI编码， 参数在元组中找到。执行全面的类型检查，确保类型与函数签名相符。结果等于 abi.encodeWithSelector(functionPointer.selector(..))。

abi.encodeWithSignature(string memory signature, ...) returns (bytes memory)： 
等价于 abi.encodeWithSelector(bytes4(keccak256(bytes(signature))), ...)

*/

/// 完善ABIEncoder合约的encodeUint和encodeMultiple函数，使用abi.encode对参数进行编码并返回
contract ABIEncoder {
    function encodeUint(uint256 value) public pure returns (bytes memory) {
        //
        return abi.encode(value);
    }

    function encodeMultiple(
        uint num,
        string memory text
    ) public pure returns (bytes memory) {
       //
       return abi.encode(num, text);
    }
}
/// 完善ABIDecoder合约的decodeUint和decodeMultiple函数， 使用abi.decode将字节数组解码成对应类型的数据
contract ABIDecoder {
    function decodeUint(bytes memory data) public pure returns (uint) {
        //
        return abi.decode(data, (uint));
    }

    function decodeMultiple(
        bytes memory data
    ) public pure returns (uint, string memory) {
        //
        return abi.decode(data, (uint, string));
    }
}

/*

## 三个 ABI 编码函数的对比
### 1. abi.encodeWithSelector
- 用途 ：使用已知的函数选择器进行编码
- 特点 ：需要手动提供 4 字节的函数选择器
- 性能 ：最高效，因为选择器已经计算好
### 2. abi.encodeWithSignature
- 用途 ：使用函数签名字符串进行编码
- 特点 ：自动计算函数选择器
- 性能 ：较低效，需要运行时计算哈希
### 3. abi.encodeCall
- 用途 ：使用函数指针进行编码
- 特点 ：提供编译时类型检查
- 性能 ：高效，且最安全
*/