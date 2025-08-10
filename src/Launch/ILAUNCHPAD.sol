// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

/**
 * @title ILAUNCHPAD
 * @dev 启动板合约接口，定义了启动板的核心功能
 * @notice 该接口规范了启动板合约必须实现的基本功能
 */
interface ILAUNCHPAD {
    /**
     * @dev 用户使用ETH参与启动板投资
     * @notice 用户发送ETH到合约参与代币发行
     */
    function participateWithEth() external payable;

    /**
     * @dev 用户参与预售阶段
     * @notice 在预售阶段用户可以以优惠价格购买代币
     */
    function participateInPresale() external payable;

    /**
     * @dev 管理员提取ETH资金
     * @param _amount 要提取的ETH数量
     * @notice 只有授权管理员可以提取筹集的资金
     */
    function WithdrawEther(uint _amount) external;

    /**
     * @dev 切换某个布尔状态
     * @param _state 要设置的布尔值
     * @return 操作是否成功
     * @notice 用于控制合约的某些开关状态
     */
    function flip(bool _state) external returns (bool);

    /**
     * @dev 调用flip函数的包装器
     * @notice 提供一个无参数的flip调用方式
     */
    function callFlip() external;
}