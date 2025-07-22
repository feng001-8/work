// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 简单的ERC721 NFT合约
contract SimpleNFT {
    string public name;
    string public symbol;
    
    // NFT所有者映射
    mapping(uint256 => address) private _owners;
    
    // 所有者NFT数量映射
    mapping(address => uint256) private _balances;
    
    // NFT授权映射
    mapping(uint256 => address) private _tokenApprovals;
    
    // 所有者对操作员的授权映射
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    
    // 当前NFT ID计数器
    uint256 private _currentTokenId;
    
    // 事件
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        _currentTokenId = 1; // 从1开始
    }
    
    // 查询NFT所有者
    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }
    
    // 查询地址拥有的NFT数量
    function balanceOf(address owner) public view returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }
    
    // 查询NFT的授权地址
    function getApproved(uint256 tokenId) public view returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }
    
    // 查询是否授权给操作员
    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }
    
    // 授权NFT给指定地址
    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "ERC721: approve caller is not owner nor approved for all"
        );
        
        _approve(to, tokenId);
    }
    
    // 设置或取消操作员授权
    function setApprovalForAll(address operator, bool approved) public {
        require(operator != msg.sender, "ERC721: approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    // 转移NFT
    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }
    
    // 安全转移NFT
    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }
    
    // 带数据的安全转移NFT
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }
    
    // 铸造NFT
    function mint(address to) public returns (uint256) {
        require(to != address(0), "ERC721: mint to the zero address");
        
        uint256 tokenId = _currentTokenId;
        _currentTokenId++;
        
        _balances[to] += 1;
        _owners[tokenId] = to;
        
        emit Transfer(address(0), to, tokenId);
        return tokenId;
    }
    
    // 批量铸造NFT
    function batchMint(address to, uint256 amount) public returns (uint256[] memory) {
        require(to != address(0), "ERC721: mint to the zero address");
        require(amount > 0, "Amount must be greater than 0");
        
        uint256[] memory tokenIds = new uint256[](amount);
        
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _currentTokenId;
            _currentTokenId++;
            
            _balances[to] += 1;
            _owners[tokenId] = to;
            tokenIds[i] = tokenId;
            
            emit Transfer(address(0), to, tokenId);
        }
        
        return tokenIds;
    }
    
    // 获取下一个将要铸造的NFT ID
    function nextTokenId() public view returns (uint256) {
        return _currentTokenId;
    }
    
    // 检查NFT是否存在
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _owners[tokenId] != address(0);
    }
    
    // 检查是否有权限操作NFT
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }
    
    // 内部转移函数
    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");
        
        // 清除授权
        _approve(address(0), tokenId);
        
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;
        
        emit Transfer(from, to, tokenId);
    }
    
    // 内部授权函数
    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }
    
    // 安全转移函数
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }
    
    // 检查接收方是否能接收NFT
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) private returns (bool) {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
}

// ERC721接收器接口
interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}