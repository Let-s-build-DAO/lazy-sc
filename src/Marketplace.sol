// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract MarketPlace is Ownable, ERC1155Holder, ReentrancyGuard {
    //////////////
    // Errors //
    /////////////
    // MarketPlace__
    error MarketPlace__ItemNotFound();
    error MarketPlace__NotAskingPrice();
    error MarketPlace__OutOfSale();

    /////////////////////
    // State variables //
    /////////////////////
    uint96 public s_itemCounter = 1;
    uint96 public s_soldItems = 0;
    uint96 public s_salePercentage = 5;
    IERC1155 public immutable i_nftContract;

    struct s_MarketItem {
        uint96 itemId;
        uint96 tokenId;
        address payable seller;
        uint256 price;
        bool claimable;
        uint96 suppy;
    }

    struct s_UserItem {
        uint96 itemId;
        uint96 tokenId;
        uint96 suppy;
    }

    mapping(uint96 => s_MarketItem) private s_idToMarketItem;
    mapping(address => mapping(uint96 => s_UserItem)) public s_userPurchases;

    /////////////////////
    // Events        ///
    ////////////////////

    event MarketItemCreated(
        uint96 indexed itemId,
        uint96 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold,
        uint96 supply
    );

    event MarketItemSold(uint96 indexed itemId, uint96 indexed tokenId, address buyer, uint256 price, uint96 supply);

    /////////////////////
    // Functions       //
    /////////////////////

    constructor(address nftContract) Ownable(msg.sender) {
        i_nftContract = IERC1155(nftContract);
    }

    function createMarketItem(uint96 tokenId, uint256 price, uint96 supply) external payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");

        s_itemCounter++;
        uint96 itemId = s_itemCounter;

        s_idToMarketItem[itemId] = s_MarketItem(itemId, tokenId, payable(msg.sender), price, false, supply);

        IERC1155(i_nftContract).safeTransferFrom(msg.sender, address(this), tokenId, supply, msg.data);

        emit MarketItemCreated(itemId, tokenId, msg.sender, address(0), price, false, supply);
    }

    function createMarketSale(uint96 itemId, uint96 supply) external payable nonReentrant {
        s_MarketItem memory marketItem = s_idToMarketItem[itemId];
        if (marketItem.seller == address(0)) {
            revert MarketPlace__ItemNotFound();
        }

        uint256 cost = supply * marketItem.price;

        if (msg.value < cost) {
            revert MarketPlace__NotAskingPrice();
        }

        // require(msg.value == marketItem.price, "Please submit the asking price in order to complete the purchase");

        IERC1155(i_nftContract).safeTransferFrom(address(this), msg.sender, marketItem.tokenId, supply, msg.data);
        // s_idToMarketItem[itemId].owner = payable(msg.sender);

        s_soldItems++;
        // Record the purchase
        s_UserItem memory userPerchase = s_userPurchases[msg.sender][itemId];

        if (userPerchase.itemId <= 0) {
            s_userPurchases[msg.sender][itemId] = s_UserItem(itemId, marketItem.tokenId, supply);
        } else {
            s_userPurchases[msg.sender][itemId].suppy += supply;
        }

        // Calculate percentage
        uint256 fee = marketItem.price * s_salePercentage / 100;
        uint256 creatorAmount = marketItem.price - fee;
        s_idToMarketItem[itemId].seller.transfer(creatorAmount);

        emit MarketItemSold(itemId, marketItem.tokenId, msg.sender, cost, supply);
    }

    function getUserPurchases(address user, uint96 itemId) external view returns (s_UserItem memory) {
        return s_userPurchases[user][itemId];
    }

    // Function to get all NFTs purchased by a user
    function getAllUserPurchases(address user) external view returns (s_UserItem[] memory) {
        s_UserItem[] memory userItems = new s_UserItem[](s_itemCounter);

        uint256 counter = 0;
        for (uint96 i = 1; i <= s_itemCounter; i++) {
            if (s_userPurchases[user][i].itemId > 0) {
                userItems[counter] = s_userPurchases[user][i];
                counter++;
            }
        }

        // Resize arrays to fit actual data
        s_UserItem[] memory userNFT = new s_UserItem[](counter);
        for (uint96 i = 0; i < counter; i++) {
            userNFT[i] = userItems[i];
        }

        return userNFT;
    }
}
