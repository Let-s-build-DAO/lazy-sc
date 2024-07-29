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
    error MarketPlace__OutOfSupply();
    error MarketPlace__ItemIsNotClaimable();
    error MarketPlace__ItemClaimed();

    /////////////////////
    // State variables //
    /////////////////////
    uint96 public s_itemsCounter = 1;
    uint96 public s_soldItemsCounter = 0;

    uint96 public s_claimableCounter = 1;
    uint96 public s_claimedItemsCounter = 0;

    uint96 public s_salePercentage = 5;
    IERC1155 public immutable i_nftContract;

    struct s_MarketItem {
        uint96 itemId;
        uint96 tokenId;
        address payable seller;
        uint256 price;
        uint96 suppy;
    }

    struct s_ClaimableItem {
        uint96 itemId;
        uint96 tokenId;
        address giver;
        uint96 suppy;
    }

    struct s_UserItem {
        uint96 itemId;
        uint96 tokenId;
        uint96 suppy;
    }

    mapping(uint96 => s_MarketItem) public s_idToMarketItem;
    mapping(uint96 => s_ClaimableItem) public s_idToClaimableItem;
    mapping(address => mapping(uint96 => s_UserItem)) public s_userPurchases;

    /////////////////////
    // Events        ///
    ////////////////////

    event MarketItemCreated(
        uint96 indexed itemId, uint96 indexed tokenId, address seller, uint256 price, uint96 supply
    );

    event ClaimableItemCreated(uint96 indexed itemId, uint96 indexed tokenId, address giver, uint96 supply);

    event MarketItemSold(uint96 indexed itemId, uint96 indexed tokenId, address buyer, uint256 price, uint96 supply);

    event MarketItemClaimed(uint96 indexed itemId, uint96 indexed tokenId, address giver, uint96 supply);

    /////////////////////
    // Functions       //
    /////////////////////

    constructor(address nftAddress) Ownable(msg.sender) {
        i_nftContract = IERC1155(nftAddress);
    }

    function createMarketItem(uint96 tokenId, uint256 price, uint96 supply) external nonReentrant {
        require(price > 0, "Price must be at least 1 wei");
        require(supply > 0, "supply can not be zero");

        uint96 itemId = s_itemsCounter;
        s_itemsCounter++;

        s_idToMarketItem[itemId] = s_MarketItem(itemId, tokenId, payable(msg.sender), price, supply);

        IERC1155(i_nftContract).safeTransferFrom(msg.sender, address(this), tokenId, supply, msg.data);

        emit MarketItemCreated(itemId, tokenId, msg.sender, price, supply);
    }

    function createClaimableItem(uint96 tokenId, uint96 supply) external nonReentrant {
        uint96 itemId = s_claimableCounter;
        s_claimableCounter++;

        s_idToClaimableItem[itemId] = s_ClaimableItem(itemId, tokenId, msg.sender, supply);

        IERC1155(i_nftContract).safeTransferFrom(msg.sender, address(this), tokenId, supply, msg.data);

        emit ClaimableItemCreated(itemId, tokenId, msg.sender, supply);
    }

    function createMarketSale(uint96 itemId, uint96 supply) external payable nonReentrant {
        s_MarketItem memory marketItem = s_idToMarketItem[itemId];

        if (marketItem.itemId == 0) {
            revert MarketPlace__ItemNotFound();
        }

        if (marketItem.suppy < 1) {
            revert MarketPlace__OutOfSale();
        }

        uint256 cost = supply * marketItem.price;

        if (msg.value < cost) {
            revert MarketPlace__NotAskingPrice();
        }

        uint96 remainingSupply = marketItem.suppy - supply;

        if (remainingSupply < 1) {
            s_soldItemsCounter++;
        }

        IERC1155(i_nftContract).safeTransferFrom(address(this), msg.sender, marketItem.tokenId, supply, msg.data);

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

    function claimNft(uint96 itemId) external nonReentrant {
        // Find market item
        s_ClaimableItem memory claimableItem = s_idToClaimableItem[itemId];

        if (claimableItem.itemId == 0) {
            revert MarketPlace__ItemNotFound();
        }

        if (claimableItem.suppy < 1) {
            revert MarketPlace__OutOfSupply();
        }

        // Check if user already has claimed this item
        s_UserItem memory item = s_userPurchases[msg.sender][itemId];
        if (item.itemId > 0) {
            revert MarketPlace__ItemClaimed();
        }

        s_userPurchases[msg.sender][itemId] = s_UserItem(itemId, claimableItem.tokenId, 1);

        IERC1155(i_nftContract).safeTransferFrom(address(this), msg.sender, claimableItem.tokenId, 1, msg.data);

        emit MarketItemClaimed(itemId, claimableItem.tokenId, claimableItem.giver, 1);
    }

    /* Returns all unsold market items */
    function fetchMarketItems() public view returns (s_MarketItem[] memory) {
        uint96 itemCount = s_itemsCounter;
        uint96 unsoldItemCount = s_itemsCounter - s_soldItemsCounter;
        uint96 currentIndex = 0;

        s_MarketItem[] memory items = new s_MarketItem[](unsoldItemCount);
        for (uint96 i = 0; i < itemCount; i++) {
            if (s_idToMarketItem[i + 1].suppy > 0) {
                uint96 currentId = i + 1;
                s_MarketItem storage currentItem = s_idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function fetchClaimableItems() public view returns (s_ClaimableItem[] memory) {
        uint96 itemCount = s_claimableCounter;
        uint96 unclaimedItemCount = s_claimableCounter - s_claimedItemsCounter;
        uint96 currentIndex = 0;

        s_ClaimableItem[] memory items = new s_ClaimableItem[](unclaimedItemCount);
        for (uint96 i = 0; i < itemCount; i++) {
            if (s_idToClaimableItem[i + 1].suppy > 0) {
                uint96 currentId = i + 1;
                s_ClaimableItem storage currentItem = s_idToClaimableItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function withdraw(address payable _payableAddress) external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0);
        _payableAddress.transfer(balance);
    }

    function getUserPurchases(address user, uint96 itemId) external view returns (s_UserItem memory) {
        return s_userPurchases[user][itemId];
    }

    // Function to get all NFTs purchased by a user
    function getAllUserPurchases(address user) external view returns (s_UserItem[] memory) {
        s_UserItem[] memory userItems = new s_UserItem[](s_itemsCounter);

        uint256 counter = 0;
        for (uint96 i = 1; i <= s_itemsCounter; i++) {
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

    /* Returns only items a user has created */
    function fetchItemsCreated() external view returns (s_MarketItem[] memory) {
        uint96 totalItemCount = s_itemsCounter;
        uint96 itemCount = 0;
        uint96 currentIndex = 0;

        for (uint96 i = 0; i < totalItemCount; i++) {
            if (s_idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        s_MarketItem[] memory items = new s_MarketItem[](itemCount);
        for (uint96 i = 0; i < totalItemCount; i++) {
            if (s_idToMarketItem[i + 1].seller == msg.sender) {
                uint96 currentId = i + 1;
                s_MarketItem storage currentItem = s_idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
}
