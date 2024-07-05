// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LazyNFTMarketplace is ERC721URIStorage, Ownable {
     constructor() ERC721("LazyNFTs", "LNFT") Ownable(msg.sender) {}
     uint256 public tokenCounter;
     mapping(uint256 => string) public tokenType;
     mapping(uint256 => bool) public forSale;
     mapping(uint256 => uint256) public salePrice;

    struct LazyNFT {
        string role;
        string uri;
        }
        
        event Minted(uint256 indexed tokenId, string role, string uri);
         event ListedForSale(uint256 indexed tokenId, uint256 price);
         event Purchased(uint256 indexed tokenId, address indexed buyer, uint256 price);
         
         function mintNFT(address recipient, LazyNFT memory lazyNFT) public onlyOwner returns (uint256) {
             uint256 newTokenId = tokenCounter;
              _safeMint(recipient, newTokenId);
              _setTokenURI(newTokenId, lazyNFT.uri);
              tokenType[newTokenId] = lazyNFT.role;
              tokenCounter += 1;
              
              emit Minted(newTokenId, lazyNFT.role, lazyNFT.uri);
              
               return newTokenId;
               }
               
               function listForSale(uint256 tokenId, uint256 price) public {
                require(ownerOf(tokenId) == msg.sender, "You are not the owner");
                require(price > 0, "Price must be greater than 0");
                
                forSale[tokenId] = true;
                salePrice[tokenId] = price;
                
                emit ListedForSale(tokenId, price);
                }
                
                function purchase(uint256 tokenId) public payable {
                    require(forSale[tokenId], "This NFT is not for sale");
                    require(msg.value == salePrice[tokenId], "Incorrect price");
                    
                    
                    address seller = ownerOf(tokenId);
                    _transfer(seller, msg.sender, tokenId);
                    
                    payable(seller).transfer(msg.value);
                    forSale[tokenId] = false;
                    
                    emit Purchased(tokenId, msg.sender, msg.value);
                    }

   function getNFTDetails(uint256 tokenId) public view returns (string memory role, string memory uri, bool isForSale, uint256 price) {
    role = tokenType[tokenId];
    uri = tokenURI(tokenId);
     isForSale = forSale[tokenId];
     price = salePrice[tokenId];
     }
}