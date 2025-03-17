// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SyntheticNFT is ERC721, Ownable {
    uint256 private _nextTokenId;

    struct SyntheticNFTData {
        uint256 assetId;
        uint256 permissions;
        uint256 startTime;
        uint256 endTime;
    }

    mapping(uint256 => SyntheticNFTData) public syntheticNFTData;
    mapping(uint256 => bool) public isBurned; // Track burned synthetic NFTs

    event SyntheticNFTMinted(uint256 indexed syntheticId, uint256 assetId, uint256 permissions, uint256 startTime, uint256 endTime, address recipient);
    event SyntheticNFTBurned(uint256 indexed syntheticId);

    constructor() ERC721("SyntheticNFT", "SNFT") Ownable(msg.sender) {
        _nextTokenId = 1;
    }

    function mintSyntheticNFT(
        uint256 assetId,
        uint256 permissions,
        uint256 startTime,
        uint256 endTime,
        address recipient
    ) public onlyOwner returns (uint256) {
        uint256 newItemId = _nextTokenId++;
        syntheticNFTData[newItemId] = SyntheticNFTData(
            assetId,
            permissions,
            startTime,
            endTime
        );
        _safeMint(recipient, newItemId);
        emit SyntheticNFTMinted(newItemId, assetId, permissions, startTime, endTime, recipient);
        return newItemId;
    }

    function hasPermission(uint256 syntheticId, uint256 permissionToCheck) public view returns (bool) {
        require(syntheticNFTData[syntheticId].assetId > 0, "SyntheticNFT: Synthetic NFT does not exist");
        SyntheticNFTData memory data = syntheticNFTData[syntheticId];
        uint256 currentTime = block.timestamp;

        bool isWithinTimeRange = (data.startTime == 0 || currentTime >= data.startTime) &&
                                  (data.endTime == 0 || currentTime <= data.endTime);

        return isWithinTimeRange && (data.permissions & permissionToCheck) == permissionToCheck;
    }

    function burn(uint256 tokenId) public onlyOwner {
        require(!isBurned[tokenId], "SyntheticNFT: Synthetic NFT already burned");
        super._burn(tokenId);
        isBurned[tokenId] = true;
        emit SyntheticNFTBurned(tokenId);
    }


    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(syntheticNFTData[tokenId].assetId > 0, "SyntheticNFT: Synthetic NFT does not exist");
        SyntheticNFTData memory data = syntheticNFTData[tokenId];
        return string(abi.encodePacked(
            "data:application/json,{\"name\": \"Synthetic NFT #",
            Strings.toString(tokenId),
            "\", \"description\": \"Represents permissions for Asset NFT #",
            Strings.toString(data.assetId),
            "\", \"attributes\": [{\"trait_type\": \"Asset ID\", \"value\": \"",
            Strings.toString(data.assetId),
            "\"}, {\"trait_type\": \"Permissions\", \"value\": \"",
            Strings.toString(data.permissions),
            "\"}, {\"trait_type\": \"Start Time\", \"value\": \"",
            data.startTime == 0 ? "None" : Strings.toString(data.startTime),
            "\"}, {\"trait_type\": \"End Time\", \"value\": \"",
            data.endTime == 0 ? "None" : Strings.toString(data.endTime),
            "\"}]}"
        ));
    }
}