// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAssetSplitter {
    struct PermissionSet {
        uint256 permissions; // Bitmap of permissions
        uint256 startTime; // Unix timestamp, 0 means no start restriction
        uint256 endTime; // Unix timestamp, 0 means no expiration
    }

    // Split an AssetNFT into multiple SyntheticNFTs
    function splitAsset(
        uint256 assetTokenId,
        PermissionSet[] calldata permissionSets
    ) external returns (uint256[] memory syntheticTokenIds);

    // Check if a SyntheticNFT has a specific permission at the current time
    function hasPermission(
        uint256 syntheticTokenId,
        uint256 permission
    ) external view returns (bool);

    // Merge SyntheticNFTs back into an AssetNFT
    function mergeAsset(
        uint256 assetTokenId,
        uint256[] calldata syntheticTokenIds
    ) external returns (uint256 newAssetTokenId);
}