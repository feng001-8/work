// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice The token and amount details for a transfer signed in the permit transfer signature
struct TokenPermissions {
    // ERC20 token address
    address token;
    // the maximum amount that can be spent
    uint256 amount;
}

/// @notice The signed permit message for a single token transfer
struct PermitTransferFrom {
    TokenPermissions permitted;
    // a unique value for every token owner's signature to prevent signature replays
    uint256 nonce;
    // deadline on the permit signature
    uint256 deadline;
}

/// @notice Specifies the recipient address and amount for batched transfers.
struct SignatureTransferDetails {
    // recipient address
    address to;
    // spender requested amount
    uint256 requestedAmount;
}

/// @title IPermit2
/// @notice Permit2 handles signature-based transfers
interface IPermit2 {
    /// @notice Transfers a token using a signed permit message
    /// @param permit The permit data signed over by the owner
    /// @param transferDetails The spender's requested transfer details for the permitted token
    /// @param owner The owner of the tokens to transfer
    /// @param signature The signature to verify
    function permitTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}