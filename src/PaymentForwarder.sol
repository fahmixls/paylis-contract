// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract PaymentForwarder is EIP712, Ownable, ReentrancyGuard, Pausable {
    using ECDSA for bytes32;

    struct MetaTx {
        address from;
        address to;
        IERC20 token;
        uint256 amount;
        uint256 nonce;
        uint256 deadline;
    }

    struct MetaTxWithSig {
        MetaTx metaTx;
        bytes signature;
    }

    struct SplitPayment {
        address from;
        address to;
        IERC20 token;
        uint256 total;
        uint256 fee;
        uint256 nonce;
        uint256 deadline;
    }

    struct SplitPaymentWithSig {
        SplitPayment splitPayment;
        bytes signature;
    }

    bytes32 private constant _METATX_TYPEHASH =
        keccak256("MetaTx(address from,address to,address token,uint256 amount,uint256 nonce,uint256 deadline)");
    
    bytes32 private constant _SPLITPAYMENT_TYPEHASH =
        keccak256("SplitPayment(address from,address to,address token,uint256 total,uint256 fee,uint256 nonce,uint256 deadline)");

    mapping(address => uint256) private nonces;
    mapping(IERC20 => bool) private whitelistedTokens;
    mapping(IERC20 => uint256) private accumulatedFees;
    
    event TokenWhitelisted(address indexed token);
    event TokenRemovedFromWhitelist(address indexed token);
    event MetaTransactionExecuted(address indexed from, address indexed to, address indexed token, uint256 amount);
    event SplitPaymentExecuted(address indexed from, address indexed to, address indexed token, uint256 total, uint256 fee);
    event FeesWithdrawn(address indexed token, uint256 amount);
    event BatchTransferCompleted(uint256 successfulTransactions, uint256 totalTransactions);

    constructor(address _owner) EIP712("PaymentMetaTx", "1") Ownable(_owner) {}

    /**
     * @dev Verifies signature based on EIP712 for MetaTx
     */
    function verifyMetaTx(MetaTx calldata _tx, bytes calldata _signature) internal view returns (bool) {
        if (block.timestamp > _tx.deadline) return false;
        
        address signer = _hashTypedDataV4(
            keccak256(abi.encode(_METATX_TYPEHASH, _tx.from, _tx.to, _tx.token, _tx.amount, _tx.nonce, _tx.deadline))
        ).recover(_signature);
        
        return signer == _tx.from && nonces[_tx.from] == _tx.nonce;
    }

    /**
     * @dev Verifies signature based on EIP712 for SplitPayment
     */
    function verifySplitPayment(SplitPayment calldata _payment, bytes calldata _signature) internal view returns (bool) {
        if (block.timestamp > _payment.deadline) return false;
        
        address signer = _hashTypedDataV4(
            keccak256(abi.encode(_SPLITPAYMENT_TYPEHASH, _payment.from, _payment.to, _payment.token, _payment.total, _payment.fee, _payment.nonce, _payment.deadline))
        ).recover(_signature);
        
        return signer == _payment.from && nonces[_payment.from] == _payment.nonce;
    }

    /**
     * @dev Transfer bundled meta transactions in batch
     */
    function batchTransfer(MetaTxWithSig[] calldata _metaTxWithSig, uint256 gas) external whenNotPaused nonReentrant {
        uint256 transactionsLength = _metaTxWithSig.length;
        uint256 successfulTransactions = 0;
        
        for (uint256 i = 0; i < transactionsLength; ++i) {
            bytes calldata signature = _metaTxWithSig[i].signature;
            MetaTx calldata metaTx = _metaTxWithSig[i].metaTx;
            
            if (verifyMetaTx(metaTx, signature) && 
                whitelistedTokens[IERC20(metaTx.token)] && 
                metaTx.to != address(0) &&
                metaTx.amount > 0) {
                
                nonces[metaTx.from] = nonces[metaTx.from] + 1;
                
                bool success = metaTx.token.transferFrom(metaTx.from, metaTx.to, metaTx.amount);
                if (success) {
                    successfulTransactions++;
                    emit MetaTransactionExecuted(metaTx.from, metaTx.to, address(metaTx.token), metaTx.amount);
                }
            }
            
            require(gasleft() > gas / 63, "Not enough gas");
        }
        
        emit BatchTransferCompleted(successfulTransactions, transactionsLength);
    }

    /**
     * @dev Execute split payment - fee stays in contract, remainder goes to receiver
     * @param _payment Split payment details with signature
     */
    function executeSplitPayment(SplitPaymentWithSig calldata _payment) external whenNotPaused nonReentrant {
        SplitPayment calldata payment = _payment.splitPayment;
        
        require(verifySplitPayment(payment, _payment.signature), "Invalid signature");
        require(whitelistedTokens[payment.token], "Token not whitelisted");
        require(payment.to != address(0), "Invalid receiver");
        require(payment.total > payment.fee, "Fee cannot be greater than or equal to total");
        require(payment.fee > 0, "Fee must be greater than 0");
        
        nonces[payment.from] = nonces[payment.from] + 1;
        
        uint256 receiverAmount = payment.total - payment.fee;
        
        // Transfer total amount from sender to this contract first
        require(payment.token.transferFrom(payment.from, address(this), payment.total), "Transfer failed");
        
        // Transfer receiver amount to receiver
        require(payment.token.transfer(payment.to, receiverAmount), "Transfer to receiver failed");
        
        // Track accumulated fees
        accumulatedFees[payment.token] += payment.fee;
        
        emit SplitPaymentExecuted(payment.from, payment.to, address(payment.token), payment.total, payment.fee);
    }

    /**
     * @dev Batch execute split payments
     */
    function batchSplitPayment(SplitPaymentWithSig[] calldata _payments, uint256 gas) external whenNotPaused nonReentrant {
        uint256 paymentsLength = _payments.length;
        uint256 successfulPayments = 0;
        
        for (uint256 i = 0; i < paymentsLength; ++i) {
            SplitPayment calldata payment = _payments[i].splitPayment;
            
            if (verifySplitPayment(payment, _payments[i].signature) &&
                whitelistedTokens[payment.token] &&
                payment.to != address(0) &&
                payment.total > payment.fee &&
                payment.fee > 0) {
                
                nonces[payment.from] = nonces[payment.from] + 1;
                
                uint256 receiverAmount = payment.total - payment.fee;
                
                bool transferFromSuccess = payment.token.transferFrom(payment.from, address(this), payment.total);
                if (transferFromSuccess) {
                    bool transferToSuccess = payment.token.transfer(payment.to, receiverAmount);
                    if (transferToSuccess) {
                        accumulatedFees[payment.token] += payment.fee;
                        successfulPayments++;
                        emit SplitPaymentExecuted(payment.from, payment.to, address(payment.token), payment.total, payment.fee);
                    }
                }
            }
            
            require(gasleft() > gas / 63, "Not enough gas");
        }
        
        emit BatchTransferCompleted(successfulPayments, paymentsLength);
    }

    /**
     * @dev Whitelist a token
     * @param _token ERC20 token address
     */
    function whitelistToken(IERC20 _token) external onlyOwner {
        require(address(_token) != address(0), "Invalid token address");
        require(!whitelistedTokens[_token], "Already whitelisted");
        
        whitelistedTokens[_token] = true;
        emit TokenWhitelisted(address(_token));
    }

    /**
     * @dev Remove token from whitelist
     * @param _token ERC20 token address
     */
    function removeTokenFromWhitelist(IERC20 _token) external onlyOwner {
        require(whitelistedTokens[_token], "Token not whitelisted");
        
        whitelistedTokens[_token] = false;
        emit TokenRemovedFromWhitelist(address(_token));
    }

    /**
     * @dev Withdraw accumulated fees for a specific token to owner
     * @param _token Token to withdraw fees for
     */
    function withdrawFees(IERC20 _token) external onlyOwner nonReentrant {
        uint256 feeAmount = accumulatedFees[_token];
        require(feeAmount > 0, "No fees to withdraw");
        
        accumulatedFees[_token] = 0;
        require(_token.transfer(owner(), feeAmount), "Fee withdrawal failed");
        
        emit FeesWithdrawn(address(_token), feeAmount);
    }

    /**
     * @dev Withdraw all accumulated fees for multiple tokens to owner
     * @param _tokens Array of tokens to withdraw fees for
     */
    function withdrawAllFees(IERC20[] calldata _tokens) external onlyOwner nonReentrant {
        for (uint256 i = 0; i < _tokens.length; i++) {
            uint256 feeAmount = accumulatedFees[_tokens[i]];
            if (feeAmount > 0) {
                accumulatedFees[_tokens[i]] = 0;
                require(_tokens[i].transfer(owner(), feeAmount), "Fee withdrawal failed");
                emit FeesWithdrawn(address(_tokens[i]), feeAmount);
            }
        }
    }

    /**
     * @dev Emergency withdrawal function (only owner)
     * @param _token Token to withdraw
     * @param _amount Amount to withdraw
     */
    function emergencyWithdraw(IERC20 _token, uint256 _amount) external onlyOwner nonReentrant {
        require(_token.transfer(owner(), _amount), "Emergency withdrawal failed");
    }

    /**
     * @dev Get nonce of the requester
     * @param _account Requester address
     */
    function getNonce(address _account) public view returns (uint256) {
        return nonces[_account];
    }

    /**
     * @dev Get accumulated fees for a token
     * @param _token Token address
     */
    function getAccumulatedFees(IERC20 _token) public view returns (uint256) {
        return accumulatedFees[_token];
    }

    /**
     * @dev Check if token is whitelisted
     * @param _token Token address
     */
    function isTokenWhitelisted(IERC20 _token) public view returns (bool) {
        return whitelistedTokens[_token];
    }

    /**
     * @dev Pause the contract (emergency function)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
}