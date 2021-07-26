// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @notice Service Fee contract for Refinable NFT Marketplace
 */
contract ServiceFee is AccessControl {
    using Address for address;

    bytes32 public constant PROXY_ROLE = keccak256("PROXY_ROLE");

    /// @notice Service fee recipient address
    address payable public serviceFeeRecipient;

    /// @notice sell service fee bps
    uint256 public sellServiceFeeBps = 250;

    /// @notice buy service fee bps
    uint256 public buyServiceFeeBps = 250;

    event ServiceFeeRecipientChanged(address payable serviceFeeRecipient);

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Ownable: caller is not the admin"
        );
        _;
    }

    modifier onlyProxy() {
        require(
            hasRole(PROXY_ROLE, _msgSender()),
            "Ownable: caller is not the proxy"
        );
        _;
    }

    /**
     * @dev Constructor Function
     * @param _sellServiceFeeBps sell service fee bps
     * @param _buyServiceFeeBps buy service fee bps
    */
    constructor(uint256 _sellServiceFeeBps, uint256 _buyServiceFeeBps) public {
        require(
            _msgSender() != address(0),
            "Auction: Invalid Platform Fee Recipient"
        );

        require(
            _sellServiceFeeBps != 0,
            "ServiceFee.constructor: service fee bps shouldn't be zero"
        );

        require(
            _buyServiceFeeBps != 0,
            "ServiceFee.constructor: service fee bps shouldn't be zero"
        );

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        sellServiceFeeBps = _sellServiceFeeBps;
        buyServiceFeeBps = _buyServiceFeeBps;
    }

    /**
     * @notice Admin can add proxy address
     * @param _proxyAddr address of proxy
     */
    function addProxy(address _proxyAddr) onlyAdmin external {
        require(
            _proxyAddr.isContract(),
            "ServiceFee.addProxy: address is not a contract address"
        );
        grantRole(PROXY_ROLE, _proxyAddr);
    }

    /**
     * @notice Admin can remove proxy address
     * @param _proxyAddr address of proxy
     */
    function removeProxy(address _proxyAddr) onlyAdmin external {
        require(
            _proxyAddr.isContract(),
            "ServiceFee.removeProxy: address is not a contract address"
        );
        revokeRole(PROXY_ROLE, _proxyAddr);
    }

    /**
     * @notice Calculate the seller service fee in according to the business logic and returns it
     * @param _seller address of seller
     */
    function getSellServiceFeeBps(address _seller) external view onlyProxy returns (uint256) {
        require(
            _seller != address(0),
            "ServiceFee.getSellServiceFeeBps: Zero address"
        );
        //we will have business logic here soon
        return sellServiceFeeBps;
    }

    /**
     * @notice Set seller service fee bps
     * @param _sellServiceFeeBps Sell service fee bps
     */
    function setSellServiceFeeBps(uint256 _sellServiceFeeBps) onlyProxy external {
        require(
            _sellServiceFeeBps != 0,
            "ServiceFee.setSellServiceFeeBps: seller service fee bps shouldn't be zero"
        );
        //we will have business logic here soon
        sellServiceFeeBps = _sellServiceFeeBps;
    }

    /**
     * @notice Calculate the buyer service fee in according to the business logic and returns it
     * @param _buyer address of buyer
     */
    function getBuyServiceFeeBps(address _buyer) onlyProxy external view returns (uint256) {
        require(
            _buyer != address(0),
            "ServiceFee.getBuyServiceFeeBps: Zero address"
        );
        //we will have business logic here soon
        return buyServiceFeeBps;
    }

    /**
     * @notice Set byuer service fee bps
     * @param _buyServiceFeeBps Buy service fee bps
     */
    function setBuyServiceFeeBps(uint256 _buyServiceFeeBps) onlyProxy external {
        require(
            _buyServiceFeeBps != 0,
            "ServiceFee.setBuyServiceFeeBps: buy service fee bps shouldn't be zero"
        );
        //we will have business logic here soon
        buyServiceFeeBps = _buyServiceFeeBps;
    }

    /**
     * @notice Get service fee recipient address
     */
    function getServiceFeeRecipient() onlyProxy external view returns (address payable) {
        return serviceFeeRecipient;
    }

    /**
     * @notice Set service fee recipient address
     * @param _serviceFeeRecipient address of recipient
     */
    function setServiceFeeRecipient(address payable _serviceFeeRecipient) onlyProxy external {
        require(
            _serviceFeeRecipient != address(0),
            "ServiceFee.setServiceFeeRecipient: Zero address"
        );

        serviceFeeRecipient = _serviceFeeRecipient;
        emit ServiceFeeRecipientChanged(_serviceFeeRecipient);
    }
}
