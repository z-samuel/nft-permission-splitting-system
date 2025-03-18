// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IAssetSplitter.sol";
import "./AssetNFT.sol";
import "./SyntheticNFT.sol";

contract AssetSplitter is Ownable, IAssetSplitter {
    AssetNFT public assetNFT;
    SyntheticNFT public syntheticNFT;

    uint256 public constant FULL_PERMISSIONS = 7; // PERMISSION_A | PERMISSION_B | PERMISSION_C

    // Map of original Asset NFT owners, for combining Synthetic NFTs back to Asset NFT
    mapping(uint256 => address) public originalAssetNFTOwners;

    constructor(address _assetNFT, address _syntheticNFT) Ownable(msg.sender) {
        assetNFT = AssetNFT(_assetNFT);
        syntheticNFT = SyntheticNFT(_syntheticNFT);
    }

    function splitAsset(
        uint256 assetTokenId,
        PermissionSet[] calldata permissionSets
    ) external override returns (uint256[] memory syntheticTokenIds) {
        require(assetNFT.ownerOf(assetTokenId) == msg.sender, "AssetSplitter: Only asset owner can split");
        require(assetNFT.FULL_PERMISSIONS() == FULL_PERMISSIONS, "AssetSplitter: Incompatible AssetNFT permissions"); // Ensure consistency

        uint256 numSplits = permissionSets.length;
        // Calculate the maximum possible number of Synthetic NFTs:
        // - One for each permissionSet
        // - One for the remainder for each permissionSets
        // - One for the initial remainder (before the first permissionSet)
        // - One for time gap before each permissionSets (Maybe same as above)
        // - One for the final remainder (after the last permissionSet)
        uint256 maxSyntheticNfts = 3 * numSplits + 1;

        syntheticTokenIds = new uint256[](maxSyntheticNfts);
        uint256 syntheticIdIndex = 0;

        uint256 totalPermissionsAccountedFor = 0;
        uint256 lastStartTime = 0;
        uint256 lastEndTime = 0;
        uint256 remainderPermissions = FULL_PERMISSIONS;
        address caller = msg.sender;
        uint256 originalAssetId = assetTokenId;

        // Sort permissionSets by startTime for easier processing
        PermissionSet[] memory sortedPermissionSets = new PermissionSet[](numSplits);
        for (uint256 i = 0; i < numSplits; i++) {
            sortedPermissionSets[i] = permissionSets[i];
        }
        // Simple bubble sort, can be optimized
        for (uint256 i = 0; i < numSplits - 1; i++) {
            for (uint256 j = 0; j < numSplits - i - 1; j++) {
                if (sortedPermissionSets[j].startTime > sortedPermissionSets[j + 1].startTime) {
                    PermissionSet memory temp = sortedPermissionSets[j];
                    sortedPermissionSets[j] = sortedPermissionSets[j + 1];
                    sortedPermissionSets[j + 1] = temp;
                }
            }
        }

        for (uint256 i = 0; i < numSplits; i++) {
            PermissionSet memory currentSet = sortedPermissionSets[i];
            require(currentSet.permissions > 0 && currentSet.permissions <= FULL_PERMISSIONS, "AssetSplitter: Invalid permission value");

            uint256 currentStartTime = currentSet.startTime;
            uint256 currentEndTime = currentSet.endTime;
            uint256 assignedPermissions = currentSet.permissions;

            // Handle gap SyntheticNFT before this time period
            if (currentStartTime > lastEndTime) {
                uint256 gapSyntheticId = syntheticNFT.mintSyntheticNFT(
                    originalAssetId,
                    remainderPermissions,
                    lastEndTime,
                    currentStartTime,
                    caller
                );
                syntheticTokenIds[syntheticIdIndex++] = gapSyntheticId;
            }
            if (currentStartTime > lastStartTime) {
                remainderPermissions = FULL_PERMISSIONS; // Reset for the next period
            }

            // Mint SyntheticNFT for the current permission set
            uint256 syntheticId = syntheticNFT.mintSyntheticNFT(
                originalAssetId,
                assignedPermissions,
                currentStartTime,
                currentEndTime,
                caller
            );
            syntheticTokenIds[syntheticIdIndex++] = syntheticId;
            totalPermissionsAccountedFor |= assignedPermissions;

            // Update remainder permissions and last end time
            remainderPermissions &= ~assignedPermissions;

            // Handle remainder SyntheticNFT
            if (remainderPermissions > 0) {
                if ((i < numSplits - 1 && sortedPermissionSets[i + 1].startTime > currentEndTime) || i == numSplits - 1 ) {
                    // No overlap to the next
                    uint256 remainderSyntheticId = syntheticNFT.mintSyntheticNFT(
                        originalAssetId,
                        remainderPermissions,
                        currentStartTime,
                        currentEndTime,
                        caller
                    );
                    syntheticTokenIds[syntheticIdIndex++] = remainderSyntheticId;
                } else if (i < numSplits - 1 && sortedPermissionSets[i + 1].startTime <= currentEndTime && sortedPermissionSets[i + 1].startTime > currentStartTime) {
                    // Has overlap to the next
                    uint256 remainderSyntheticId = syntheticNFT.mintSyntheticNFT(
                        originalAssetId,
                        remainderPermissions,
                        currentStartTime,
                        sortedPermissionSets[i + 1].startTime,
                        caller
                    );
                    syntheticTokenIds[syntheticIdIndex++] = remainderSyntheticId;
                }
            }
            lastEndTime = currentEndTime;
            lastStartTime = currentStartTime;
        }

        if (lastEndTime > 0) {
            // Handle the time period after lastEndTime
            uint256 syntheticId = syntheticNFT.mintSyntheticNFT(
                originalAssetId,
                FULL_PERMISSIONS,
                lastEndTime,
                0, // No end time for the final
                caller
            );
            syntheticTokenIds[syntheticIdIndex++] = syntheticId;
        }

        assetNFT.burn(originalAssetId);
        originalAssetNFTOwners[originalAssetId] = msg.sender;

        emit AssetSplit(originalAssetId, syntheticTokenIds);
        return syntheticTokenIds;
    }

    function hasPermission(
        uint256 syntheticTokenId,
        uint256 permission
    ) external view override returns (bool) {
        return syntheticNFT.hasPermission(syntheticTokenId, permission);
    }

    function mergeAsset(
        uint256 assetTokenId,
        uint256[] calldata syntheticTokenIds
    ) external override returns (uint256 newAssetTokenId) {
        require(originalAssetNFTOwners[assetTokenId] == msg.sender, "AssetSplitter: Only asset owner can merge");
        uint256 numSplits = syntheticTokenIds.length;
        require(numSplits > 0, "AssetSplitter: number of synthetic NFTs cannot be zero");
        uint256[] memory sortedSyntheticTokenIds = new uint256[](numSplits);
        for (uint256 i = 0; i < numSplits; i ++) {
            sortedSyntheticTokenIds[i] = syntheticTokenIds[i];
        }
        
        // Simple bubble sort, can be optimized
        for (uint256 i = 0; i < numSplits - 1; i++) {
            for (uint256 j = 0; j < numSplits - i - 1; j++) {
                if (sortedSyntheticTokenIds[j] > sortedSyntheticTokenIds[j + 1]) {
                    uint256 temp = sortedSyntheticTokenIds[j];
                    sortedSyntheticTokenIds[j] = sortedSyntheticTokenIds[j + 1];
                    sortedSyntheticTokenIds[j + 1] = temp;
                }
            }
        }

        (,uint256 sumPermission, uint256 curStartTime,) = syntheticNFT.syntheticNFTData(sortedSyntheticTokenIds[0]);
        require(curStartTime == 0, "AssetSplitter: full combination should have a synthetic NFT which start time is the beginning");
        for (uint256 i = 1; i < numSplits; i++) {
            (,uint256 nextPermission, uint256 nextStartTime,) = syntheticNFT.syntheticNFTData(sortedSyntheticTokenIds[i]);
            if (sumPermission == FULL_PERMISSIONS) {
                sumPermission = 0; // Reset permission
                require(nextStartTime > curStartTime, "AssetSplitter: Time range should not overlap for full permission");
            } else {
                require(nextStartTime == curStartTime, "AssetSplitter: Time range have incompleted permission");
            }
            require((sumPermission & nextPermission) == 0, "AssetSplitter: Permission should not overlaps");
            sumPermission |= nextPermission;
            curStartTime = nextStartTime;
        }
        (,,, uint256 endTime) = syntheticNFT.syntheticNFTData(sortedSyntheticTokenIds[numSplits - 1]);
        require(endTime == 0, "AssetSplitter: full combination should have a synthetic NFT which start time is the end");
        require(sumPermission == FULL_PERMISSIONS, "AssetSplitter: Synthetic NFTs do not represent the full set of permissions");
        // Mint a new AssetNFT
        newAssetTokenId = assetNFT.mintAsset(msg.sender);

        // Burn all the Synthetic NFTs
        for (uint256 i = 0; i < numSplits; i++) {
            if (syntheticTokenIds[i] == 0) {
                continue;
            }
            syntheticNFT.burn(syntheticTokenIds[i]);
        }

        emit AssetMerged(newAssetTokenId, syntheticTokenIds);
        return newAssetTokenId;
    }

    event AssetSplit(uint256 indexed assetId, uint256[] syntheticIds);
    event AssetMerged(uint256 indexed newAssetId, uint256[] syntheticIds);
}