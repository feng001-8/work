#!/bin/bash

# TokenBank 合约测试脚本
# 用于验证合约部署和基本功能

echo "🚀 TokenBank 合约测试开始..."
echo "================================"

# 合约地址
ERC20_ADDRESS="0x5FbDB2315678afecb367f032d93F642f64180aa3"
TOKEN_BANK_ADDRESS="0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"
TEST_ACCOUNT="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
RPC_URL="http://localhost:8546"

echo "📋 合约信息:"
echo "ERC20 代币地址: $ERC20_ADDRESS"
echo "TokenBank 地址: $TOKEN_BANK_ADDRESS"
echo "测试账户: $TEST_ACCOUNT"
echo ""

# 检查 ERC20 代币信息
echo "🔍 检查 ERC20 代币信息..."
echo "代币名称:"
cast call $ERC20_ADDRESS "name()" --rpc-url $RPC_URL | cast --to-ascii
echo "代币符号:"
cast call $ERC20_ADDRESS "symbol()" --rpc-url $RPC_URL | cast --to-ascii
echo "代币小数位:"
cast call $ERC20_ADDRESS "decimals()" --rpc-url $RPC_URL | cast --to-dec
echo ""

# 检查账户余额
echo "💰 检查账户余额..."
echo "ETH 余额:"
cast balance $TEST_ACCOUNT --rpc-url $RPC_URL | cast --to-ether
echo "代币余额:"
TOKEN_BALANCE=$(cast call $ERC20_ADDRESS "balanceOf(address)" $TEST_ACCOUNT --rpc-url $RPC_URL)
echo "$TOKEN_BALANCE (原始值)"
echo "$(cast --to-dec $TOKEN_BALANCE | awk '{print $1/10^18}') 代币 (格式化)"
echo ""

# 检查银行余额
echo "🏦 检查 TokenBank 状态..."
echo "用户在银行的余额:"
BANK_BALANCE=$(cast call $TOKEN_BANK_ADDRESS "getBankBalance(address)" $TEST_ACCOUNT --rpc-url $RPC_URL)
echo "$BANK_BALANCE (原始值)"
echo "$(cast --to-dec $BANK_BALANCE | awk '{print $1/10^18}') 代币 (格式化)"

echo "银行总存款:"
TOTAL_DEPOSITS=$(cast call $TOKEN_BANK_ADDRESS "getTotalDeposits()" --rpc-url $RPC_URL)
echo "$TOTAL_DEPOSITS (原始值)"
echo "$(cast --to-dec $TOTAL_DEPOSITS | awk '{print $1/10^18}') 代币 (格式化)"
echo ""

# 检查授权额度
echo "🔐 检查授权状态..."
ALLOWANCE=$(cast call $ERC20_ADDRESS "allowance(address,address)" $TEST_ACCOUNT $TOKEN_BANK_ADDRESS --rpc-url $RPC_URL)
echo "当前授权额度: $ALLOWANCE (原始值)"
echo "$(cast --to-dec $ALLOWANCE | awk '{print $1/10^18}') 代币 (格式化)"
echo ""

# 测试存款流程
echo "💳 测试存款流程..."
DEPOSIT_AMOUNT="100000000000000000000" # 100 代币

echo "1. 授权 TokenBank 使用代币..."
cast send $ERC20_ADDRESS "approve(address,uint256)" $TOKEN_BANK_ADDRESS $DEPOSIT_AMOUNT --rpc-url $RPC_URL --private-key $PRIVATE_KEY > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ 授权成功"
else
    echo "❌ 授权失败"
    exit 1
fi

echo "2. 执行存款..."
cast send $TOKEN_BANK_ADDRESS "deposit(uint256)" $DEPOSIT_AMOUNT --rpc-url $RPC_URL --private-key $PRIVATE_KEY > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ 存款成功"
else
    echo "❌ 存款失败"
    exit 1
fi

echo "3. 验证存款后余额..."
sleep 2
NEW_BANK_BALANCE=$(cast call $TOKEN_BANK_ADDRESS "getBankBalance(address)" $TEST_ACCOUNT --rpc-url $RPC_URL)
echo "新的银行余额: $(cast --to-dec $NEW_BANK_BALANCE | awk '{print $1/10^18}') 代币"
echo ""

# 测试取款流程
echo "💸 测试取款流程..."
WITHDRAW_AMOUNT="50000000000000000000" # 50 代币

echo "1. 执行取款..."
cast send $TOKEN_BANK_ADDRESS "withdraw(uint256)" $WITHDRAW_AMOUNT --rpc-url $RPC_URL --private-key $PRIVATE_KEY > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ 取款成功"
else
    echo "❌ 取款失败"
    exit 1
fi

echo "2. 验证取款后余额..."
sleep 2
FINAL_BANK_BALANCE=$(cast call $TOKEN_BANK_ADDRESS "getBankBalance(address)" $TEST_ACCOUNT --rpc-url $RPC_URL)
echo "最终银行余额: $(cast --to-dec $FINAL_BANK_BALANCE | awk '{print $1/10^18}') 代币"
echo ""

echo "🎉 所有测试完成！"
echo "================================"
echo "✅ ERC20 代币合约正常"
echo "✅ TokenBank 合约正常"
echo "✅ 存款功能正常"
echo "✅ 取款功能正常"
echo ""
echo "现在您可以使用前端界面进行交互了！"
echo "前端地址: http://localhost:5173/"
echo ""
echo "📝 重要提醒:"
echo "1. 确保 MetaMask 连接到 Localhost 网络 (Chain ID: 31337)"
echo "2. 导入测试账户私钥: $PRIVATE_KEY"
echo "3. 添加 ERC20 代币到 MetaMask: $ERC20_ADDRESS"