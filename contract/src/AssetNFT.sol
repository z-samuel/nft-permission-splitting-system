// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AssetNFT is ERC721, Ownable {
    uint256 private _nextTokenId;

    uint256 public constant FULL_PERMISSIONS = 7; // PERMISSION_A | PERMISSION_B | PERMISSION_C

    event AssetSplit(uint256 indexed assetId, uint256[] syntheticIds);

    constructor() ERC721("AssetNFT", "ANFT") Ownable(msg.sender) {
        _nextTokenId = 1;
    }

    function mintAsset() public returns (uint256) {
        uint256 newItemId = _nextTokenId++;
        _safeMint(msg.sender, newItemId);
        return newItemId;
    }

    function burn(uint256 tokenId) public {
        require(owner() == msg.sender || ownerOf(tokenId) == msg.sender, "AssetNFT: Invalid owner");
        super._burn(tokenId);
    }
}