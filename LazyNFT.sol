// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract LazyNFT {
    mapping(address => uint256) public nftCounter; 
    
    struct NFT{
        uint256 id;
        string name;
        string description;
        uint256 price;
        bool isSold;
    }

    mapping(address => mapping(uint256 => NFT)) public nfts;

    event NewNFT(uint256 id, string name, string description, uint256 prices);

    event NFTSold(uint256 id, address buyer);

    function listNewNFT(string memory _name, string memory _description, uint256 _price) public {
        nftCounter[msg.sender]++; 
        NFT memory newNFT = NFT(nftCounter[msg.sender], _name, _description, _price, false); 
        emit NewNFT(newNFT.id, newNFT.name, newNFT.description, newNFT.price); 
    }

    function buyNewNFT(uint256 _id) public payable {
        require(!nfts[msg.sender][_id].isSold, "NFT is already sold");   
    }
    
    function getNFT(address _owner, uint256 _id) public view returns (NFT memory){
        return nfts[_owner][_id];
    }
}