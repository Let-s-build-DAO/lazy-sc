// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/Lazy.sol";
import "../src/Marketplace.sol";

contract Market is Test {
  Lazy lasy;
  MarketPlace marketPlace;

  function setUp() public {
    lasy = new Lazy();
    marketPlace = new MarketPlace(address(lasy));

    // lasy.mint(address(this), 1, 80);
  }

  function test_createClaimableItem() public {
    marketPlace.createClaimableItem(1, 80);
    (, uint96 tokenId, ,) = marketPlace.s_idToClaimableItem(1);
    assertEq(tokenId, 1);
  }
}