// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../src/Lazy.sol";
import "../src/Marketplace.sol";

contract Market is Test {
    Lazy lazy;
    MarketPlace marketPlace;
    uint96 id = 1;
    uint256 supply = 80000000000000000000;

    function setUp() public {
        lazy = new Lazy();
        marketPlace = new MarketPlace(address(lazy));

        lazy.mint(address(this), id, supply);

        // lazy.setApprovalForAll(address(marketPlace), true);
    }

    // function test_createClaimableItem() public {
    //   marketPlace.createClaimableItem(id, 80);
    //   (, uint96 tokenId, ,) = marketPlace.s_idToClaimableItem(1);
    //   assertEq(tokenId, 1);
    // }

    function test_userBalance() public {
        uint256 balance = lazy.balanceOf(address(this), id);

        assertEq(balance, supply);
    }
}
