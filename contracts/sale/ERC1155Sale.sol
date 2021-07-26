// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";

import "../libs/StringLibrary.sol";
import "./ERC1155SaleNonceHolder.sol";
import "../tokens/HasSecondarySaleFees.sol";
import "../proxy/TransferProxy.sol";
import "../proxy/ServiceFeeProxy.sol";

contract ERC1155Sale {
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
        address buyer,
        uint256 value
    );

    bytes constant EMPTY = "";
    bytes4 private constant _INTERFACE_ID_FEES = 0xb7799584;

    TransferProxy public transferProxy;
    ServiceFeeProxy public serviceFeeProxy;
    ERC1155SaleNonceHolder public nonceHolder;

    constructor(
        TransferProxy _transferProxy,
        ERC1155SaleNonceHolder _nonceHolder,
        ServiceFeeProxy _serviceFeeProxy
    ) public {
        transferProxy = _transferProxy;
        nonceHolder = _nonceHolder;
        serviceFeeProxy = _serviceFeeProxy;
    }

    function buy(
        IERC1155 token,
        uint256 tokenId,
        address payable owner,
        uint256 selling,
        uint256 buying,
        bytes memory signature
    ) public payable {
        uint256 price = msg.value.div(buying);
        uint256 nonce = verifySignature(
            address(token),
            tokenId,
            owner,
            selling,
            price,
            signature
        );
        verifyOpenAndModifyState(
            address(token),
            tokenId,
            owner,
            nonce,
            selling,
            buying
        );

        transferProxy.erc1155safeTransferFrom(
            token,
            owner,
            msg.sender,
            tokenId,
            buying,
            EMPTY
        );

        transferEther(token, tokenId, owner);
        emit Buy(address(token), tokenId, owner, price, msg.sender, buying);
    }

    function transferEther(
        IERC1155 token,
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
        nonceHolder.setNonce(token, tokenId, msg.sender, nonce .add(1));

        emit CloseOrder(token, tokenId, msg.sender, nonce .add(1));
    }

    function verifySignature(
        address token,
        uint256 tokenId,
        address payable owner,
        uint256 selling,
        uint256 price,
        bytes memory signature
    ) internal view returns (uint256 nonce) {
        nonce = nonceHolder.getNonce(token, tokenId, owner);
        require(
            keccak256(abi.encodePacked(token, tokenId, price, selling, nonce))
                .toEthSignedMessageHash()
                .recover(signature) == owner,
            "incorrect signature"
        );
    }

    function verifyOpenAndModifyState(
        address token,
        uint256 tokenId,
        address payable owner,
        uint256 nonce,
        uint256 selling,
        uint256 buying
    ) internal {
        uint256 comp = nonceHolder
            .getCompleted(token, tokenId, owner, nonce)
            .add(buying);
        require(comp <= selling);
        nonceHolder.setCompleted(token, tokenId, owner, nonce, comp);

        if (comp == selling) {
            nonceHolder.setNonce(token, tokenId, owner, nonce .add(1));
            emit CloseOrder(token, tokenId, owner, nonce .add(1));
        }
    }

}