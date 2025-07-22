#!/bin/bash

# NFT市场和TokenBank DApp 综合部署脚本
# 功能：启动本地Anvil网络，部署所有合约，更新前端配置

set -e  # 遇到错误立即退出

echo "🚀 开始 NFT市场和TokenBank DApp 综合部署流程..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 检查必要的工具
check_dependencies() {
    echo -e "${BLUE}📋 检查依赖工具...${NC}"
    
    if ! command -v anvil &> /dev/null; then
        echo -e "${RED}❌ Anvil 未安装，请先安装 Foundry${NC}"
        exit 1
    fi
    
    if ! command -v forge &> /dev/null; then
        echo -e "${RED}❌ Forge 未安装，请先安装 Foundry${NC}"
        exit 1
    fi
    
    if ! command -v cast &> /dev/null; then
        echo -e "${RED}❌ Cast 未安装，请先安装 Foundry${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 所有依赖工具已安装${NC}"
}

# 清理之前的进程
cleanup() {
    echo -e "${YELLOW}🧹 清理之前的 Anvil 进程...${NC}"
    pkill -f "anvil" || true
    sleep 2
    
    # 清理旧的日志文件
    rm -f anvil.log .anvil_pid
}

# 启动 Anvil 网络
start_anvil() {
    echo -e "${BLUE}🔧 启动本地 Anvil 网络...${NC}"
    
    # 在后台启动 Anvil (使用8545端口，与前端配置一致)
    anvil --host 127.0.0.1 --port 8545 --chain-id 31337 > anvil.log 2>&1 &
    ANVIL_PID=$!
    
    echo "Anvil PID: $ANVIL_PID" > .anvil_pid
    
    # 等待 Anvil 启动
    echo -e "${YELLOW}⏳ 等待 Anvil 网络启动...${NC}"
    sleep 5
    
    # 检查 Anvil 是否正常运行
    if ! curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        http://127.0.0.1:8545 > /dev/null; then
        echo -e "${RED}❌ Anvil 启动失败${NC}"
        cat anvil.log
        exit 1
    fi
    
    echo -e "${GREEN}✅ Anvil 网络已启动 (Chain ID: 31337, Port: 8545)${NC}"
}

# 编译合约
compile_contracts() {
    echo -e "${BLUE}🔨 编译智能合约...${NC}"
    
    if ! forge build; then
        echo -e "${RED}❌ 合约编译失败${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 合约编译成功${NC}"
}

# 部署NFT市场合约
deploy_nft_market() {
    echo -e "${PURPLE}🎨 部署NFT市场合约...${NC}"
    
    # 设置环境变量
    export PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    export ETHERSCAN_API_KEY="dummy"
    
    # 部署NFT市场合约
    DEPLOY_OUTPUT=$(forge script script/DeployNFTMarket.s.sol:DeployNFTMarket \
        --rpc-url http://127.0.0.1:8545 \
        --private-key $PRIVATE_KEY \
        --broadcast \
        --skip-simulation 2>&1)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ NFT市场合约部署失败${NC}"
        echo "$DEPLOY_OUTPUT"
        exit 1
    fi
    
    # 从broadcast文件中提取合约地址
    BROADCAST_FILE="broadcast/DeployNFTMarket.s.sol/31337/run-latest.json"
    
    if [ ! -f "$BROADCAST_FILE" ]; then
        echo -e "${RED}❌ 找不到部署广播文件${NC}"
        exit 1
    fi
    
    # 提取合约地址 (按部署顺序：ERC20, SimpleNFT, NFTMarket)
    ERC20_ADDRESS=$(jq -r '.transactions[0].contractAddress' "$BROADCAST_FILE")
    SIMPLE_NFT_ADDRESS=$(jq -r '.transactions[1].contractAddress' "$BROADCAST_FILE")
    NFT_MARKET_ADDRESS=$(jq -r '.transactions[2].contractAddress' "$BROADCAST_FILE")
    
    if [ "$ERC20_ADDRESS" = "null" ] || [ "$SIMPLE_NFT_ADDRESS" = "null" ] || [ "$NFT_MARKET_ADDRESS" = "null" ]; then
        echo -e "${RED}❌ 无法提取NFT市场合约地址${NC}"
        echo "广播文件内容："
        cat "$BROADCAST_FILE"
        exit 1
    fi
    
    echo -e "${GREEN}✅ NFT市场合约部署成功${NC}"
    echo -e "${GREEN}📍 ERC20 Token: $ERC20_ADDRESS${NC}"
    echo -e "${GREEN}📍 SimpleNFT: $SIMPLE_NFT_ADDRESS${NC}"
    echo -e "${GREEN}📍 NFTMarket: $NFT_MARKET_ADDRESS${NC}"
}

# 部署TokenBank合约
deploy_token_bank() {
    echo -e "${PURPLE}🏦 部署TokenBank合约...${NC}"
    
    # 部署TokenBank合约
    DEPLOY_OUTPUT=$(forge script script/TokenBank.s.sol:DeployTokenBank \
        --rpc-url http://127.0.0.1:8545 \
        --private-key $PRIVATE_KEY \
        --broadcast 2>&1)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ TokenBank合约部署失败${NC}"
        echo "$DEPLOY_OUTPUT"
        exit 1
    fi
    
    # 从broadcast文件中提取合约地址
    TOKENBANK_BROADCAST_FILE="broadcast/TokenBank.s.sol/31337/run-latest.json"
    
    if [ ! -f "$TOKENBANK_BROADCAST_FILE" ]; then
        echo -e "${RED}❌ 找不到TokenBank部署广播文件${NC}"
        exit 1
    fi
    
    # 提取TokenBank合约地址
    TOKENBANK_ERC20_ADDRESS=$(jq -r '.transactions[0].contractAddress' "$TOKENBANK_BROADCAST_FILE")
    TOKENBANK_ADDRESS=$(jq -r '.transactions[1].contractAddress' "$TOKENBANK_BROADCAST_FILE")
    
    if [ "$TOKENBANK_ADDRESS" = "null" ]; then
        echo -e "${RED}❌ 无法提取TokenBank合约地址${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ TokenBank合约部署成功${NC}"
    echo -e "${GREEN}📍 TokenBank ERC20: $TOKENBANK_ERC20_ADDRESS${NC}"
    echo -e "${GREEN}📍 TokenBank: $TOKENBANK_ADDRESS${NC}"
}

# 更新前端配置
update_frontend_config() {
    echo -e "${BLUE}🔧 更新前端合约配置...${NC}"
    
    if [ ! -f "frontend/src/lib/contracts.ts" ]; then
        echo -e "${YELLOW}⚠️  前端配置文件不存在，跳过更新${NC}"
        return
    fi
    
    # 备份原配置
    cp frontend/src/lib/contracts.ts frontend/src/lib/contracts.ts.backup
    
    # 更新LOCALHOST配置中的合约地址
    sed -i.bak "s/ERC20_TOKEN: '[^']*'/ERC20_TOKEN: '$ERC20_ADDRESS'/g" frontend/src/lib/contracts.ts
    sed -i.bak "s/SIMPLE_NFT: '[^']*'/SIMPLE_NFT: '$SIMPLE_NFT_ADDRESS'/g" frontend/src/lib/contracts.ts
    sed -i.bak "s/NFT_MARKET: '[^']*'/NFT_MARKET: '$NFT_MARKET_ADDRESS'/g" frontend/src/lib/contracts.ts
    sed -i.bak "s/TOKEN_BANK: '[^']*'/TOKEN_BANK: '$TOKENBANK_ADDRESS'/g" frontend/src/lib/contracts.ts
    
    rm frontend/src/lib/contracts.ts.bak
    
    echo -e "${GREEN}✅ 前端配置已更新${NC}"
}

# 保存部署信息
save_deployment_info() {
    echo -e "${BLUE}💾 保存部署信息...${NC}"
    
    cat > deployment_info.json << EOF
{
  "timestamp": "$(date -Iseconds)",
  "chainId": 31337,
  "rpcUrl": "http://127.0.0.1:8545",
  "nftMarket": {
    "erc20Token": "$ERC20_ADDRESS",
    "simpleNFT": "$SIMPLE_NFT_ADDRESS",
    "nftMarket": "$NFT_MARKET_ADDRESS"
  },
  "tokenBank": {
    "erc20Token": "$TOKENBANK_ERC20_ADDRESS",
    "tokenBank": "$TOKENBANK_ADDRESS"
  },
  "accounts": {
    "deployer": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    "privateKey": "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  }
}
EOF
    
    echo -e "${GREEN}📄 部署信息已保存到 deployment_info.json${NC}"
}

# 验证部署
verify_deployment() {
    echo -e "${BLUE}🔍 验证合约部署...${NC}"
    
    # 验证NFT市场合约
    echo -e "${PURPLE}验证NFT市场合约...${NC}"
    
    # 检查ERC20代币
    TOKEN_NAME=$(cast call $ERC20_ADDRESS "name()" --rpc-url http://127.0.0.1:8545 | cast --to-ascii)
    TOKEN_SYMBOL=$(cast call $ERC20_ADDRESS "symbol()" --rpc-url http://127.0.0.1:8545 | cast --to-ascii)
    
    echo -e "${GREEN}📋 NFT市场 ERC20 代币信息:${NC}"
    echo -e "   名称: $TOKEN_NAME"
    echo -e "   符号: $TOKEN_SYMBOL"
    
    # 检查NFT合约
    NFT_NAME=$(cast call $SIMPLE_NFT_ADDRESS "name()" --rpc-url http://127.0.0.1:8545 | cast --to-ascii)
    NFT_SYMBOL=$(cast call $SIMPLE_NFT_ADDRESS "symbol()" --rpc-url http://127.0.0.1:8545 | cast --to-ascii)
    
    echo -e "${GREEN}📋 SimpleNFT 信息:${NC}"
    echo -e "   名称: $NFT_NAME"
    echo -e "   符号: $NFT_SYMBOL"
    
    # 检查NFT市场
    MARKET_TOKEN=$(cast call $NFT_MARKET_ADDRESS "paymentToken()" --rpc-url http://127.0.0.1:8545)
    
    echo -e "${GREEN}📋 NFT市场信息:${NC}"
    echo -e "   支付代币: $MARKET_TOKEN"
    
    # 验证TokenBank合约
    echo -e "${PURPLE}验证TokenBank合约...${NC}"
    
    BANK_TOKEN=$(cast call $TOKENBANK_ADDRESS "token()" --rpc-url http://127.0.0.1:8545)
    
    echo -e "${GREEN}📋 TokenBank 信息:${NC}"
    echo -e "   关联代币: $BANK_TOKEN"
    
    if [ "$BANK_TOKEN" = "$TOKENBANK_ERC20_ADDRESS" ]; then
        echo -e "${GREEN}✅ TokenBank 正确关联到 ERC20 代币${NC}"
    else
        echo -e "${RED}❌ TokenBank 代币地址不匹配${NC}"
    fi
    
    if [ "$MARKET_TOKEN" = "$ERC20_ADDRESS" ]; then
        echo -e "${GREEN}✅ NFT市场正确关联到 ERC20 代币${NC}"
    else
        echo -e "${RED}❌ NFT市场代币地址不匹配${NC}"
    fi
}

# 显示使用说明
show_usage_instructions() {
    echo -e "\n${GREEN}🎉 部署完成！${NC}"
    echo -e "\n${BLUE}📋 部署摘要:${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}🌐 网络信息:${NC}"
    echo -e "   Chain ID: 31337"
    echo -e "   RPC URL: http://127.0.0.1:8545"
    echo -e "   Anvil PID: $(cat .anvil_pid 2>/dev/null || echo 'N/A')"
    
    echo -e "\n${YELLOW}🎨 NFT市场合约:${NC}"
    echo -e "   ERC20 Token: $ERC20_ADDRESS"
    echo -e "   SimpleNFT: $SIMPLE_NFT_ADDRESS"
    echo -e "   NFTMarket: $NFT_MARKET_ADDRESS"
    
    echo -e "\n${YELLOW}🏦 TokenBank合约:${NC}"
    echo -e "   ERC20 Token: $TOKENBANK_ERC20_ADDRESS"
    echo -e "   TokenBank: $TOKENBANK_ADDRESS"
    
    echo -e "\n${YELLOW}👤 测试账户:${NC}"
    echo -e "   地址: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    echo -e "   私钥: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    
    echo -e "\n${BLUE}📖 使用说明:${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "1. ${PURPLE}配置MetaMask:${NC}"
    echo -e "   - 添加网络: Anvil Local"
    echo -e "   - RPC URL: http://127.0.0.1:8545"
    echo -e "   - Chain ID: 31337"
    echo -e "   - 货币符号: ETH"
    
    echo -e "2. ${PURPLE}导入测试账户:${NC}"
    echo -e "   - 使用上面的私钥导入账户到MetaMask"
    
    echo -e "3. ${PURPLE}启动前端:${NC}"
    echo -e "   cd frontend && npm run dev"
    
    echo -e "4. ${PURPLE}测试功能:${NC}"
    echo -e "   - NFT市场: 铸造、上架、购买NFT"
    echo -e "   - TokenBank: 存款、取款代币"
    
    echo -e "\n${YELLOW}⚠️  注意事项:${NC}"
    echo -e "   - Anvil进程在后台运行，使用 'pkill anvil' 停止"
    echo -e "   - 重启Anvil会清空所有数据，需要重新部署"
    echo -e "   - 部署信息已保存到 deployment_info.json"
    
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 主函数
main() {
    # 检查是否需要帮助
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "用法: $0 [选项]"
        echo "选项:"
        echo "  -h, --help     显示帮助信息"
        echo "  --no-cleanup   跳过清理步骤"
        echo "  --no-verify    跳过验证步骤"
        exit 0
    fi
    
    # 执行部署流程
    check_dependencies
    
    if [ "$1" != "--no-cleanup" ]; then
        cleanup
    fi
    
    start_anvil
    compile_contracts
    deploy_nft_market
    deploy_token_bank
    update_frontend_config
    save_deployment_info
    
    if [ "$1" != "--no-verify" ]; then
        verify_deployment
    fi
    
    show_usage_instructions
}

# 错误处理
trap 'echo -e "${RED}❌ 部署过程中发生错误${NC}"; exit 1' ERR

# 运行主函数
main "$@"