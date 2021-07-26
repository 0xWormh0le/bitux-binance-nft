// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "../proxy/TransferProxy.sol";
import "../proxy/ServiceFeeProxy.sol";
import "./ERC721SaleNonceHolder.sol";
import "../tokens/HasSecondarySaleFees.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";

contract ERC721Sale {
    using SafeMath for uint256;
    using ECDSA for bytes32;

    event CloseOrder(
        address indexed token,
        uint256 indexed tokenId,
        address owner,
        uint256 nonce
    );
    event Buy(
        address indexed token,
        uint256 indexed tokenId,
        address owner,
        uint256 price,
        address buyer
    );

    bytes constant EMPTY = "";
    bytes4 private constant _INTERFACE_ID_FEES = 0xb7799584;

    TransferProxy public transferProxy;
    ServiceFeeProxy public serviceFeeProxy;
    ERC721SaleNonceHolder public nonceHolder;

    constructor(
        TransferProxy _transferProxy,
        ERC721SaleNonceHolder _nonceHolder,
        ServiceFeeProxy _serviceFeeProxy
    ) public {
        transferProxy = _transferProxy;
        nonceHolder = _nonceHolder;
        serviceFeeProxy = _serviceFeeProxy;
    }

    function buy(
        IERC721 token,
        uint256 tokenId,
        address payable owner,
        bytes memory signature
    ) public payable {
        uint256 price = msg.value;
        uint256 nonce = verifySignature(
            address(token),
            tokenId,
            owner,
            price,
            signature
        );
        verifyOpenAndModifyState(address(token), tokenId, owner, nonce);

        transferProxy.erc721safeTransferFrom(token, owner, msg.sender, tokenId);

        transferEther(token, tokenId, owner);
        emit Buy(address(token), tokenId, owner, price, msg.sender);
    }

    function transferEther(
        IERC721 token,
        uint256 tokenId,
        address payable owner
    ) internal {
                uint256 sellerServiceFeeBps = serviceFeeProxy.getSellServiceFeeBps(owner);
        uint256 buyerServiceFeeBps = serviceFeeProxy.getBuyServiceFeeBps(msg.sender);
        address payable serviceFeeRecipient = serviceFeeProxy.getServiceFeeRecipient();

        uint256 tokenPrice = msg.value.div(buyerServiceFeeBps.div(100).add(100)).mul(100);
        uint256 sellerServiceFee = tokenPrice.mul(sellerServiceFeeBps).div(10000);
        uint256 ownerValue = tokenPrice.sub(sellerServiceFee);
        uint256 sumFee;

        if (token.supportsInterface(_INTERFACE_ID_FEES)) {
            HasSecondarySaleFees withFees = HasSecondarySaleFees(address(token));
            address payable[] memory recipients = withFees.getFeeRecipients(tokenId);
            uint256[] memory fees = withFees.getFeeBps(tokenId);
            require(fees.length == recipients.length);
            for (uint256 i = 0; i < fees.length; i++) {
                uint256 current = ownerValue.mul(fees[i]).div(10000);
                recipients[i].transfer(current);
                sumFee = sumFee.add(current);
            }
        }
        ownerValue = ownerValue.sub(sumFee);
        serviceFeeRecipient.transfer(sellerServiceFee.add(msg.value.sub(tokenPrice)));
        owner.transfer(ownerValue);
    }

    function cancel(address token, uint256 tokenId) public payable {
        uint256 nonce = nonceHolder.getNonce(token, tokenId, msg.sender);
        nonceHolder.setNonce(token, tokenId, msg.sender, nonce.add(1));

        emit CloseOrder(token, tokenId, msg.sender, nonce.add(1));
    }

    function verifySignature(
        address token,
        uint256 tokenId,
        address payable owner,
        uint256 price,
        bytes memory signature
    ) internal view returns (uint256 nonce) {
        nonce = nonceHolder.getNonce(token, tokenId, owner);
        require(
            keccak256(abi.encodePacked(token, tokenId, price, nonce)).toEthSignedMessageHash().recover(signature) == owner,
            "incorrect signature"
        );
    }

    function verifyOpenAndModifyState(
        address token,
        uint256 tokenId,
        address payable owner,
        uint256 nonce
    ) internal {
        nonceHolder.setNonce(token, tokenId, owner, nonce.add(1));
        emit CloseOrder(token, tokenId, owner, nonce.add(1));
    }
}
