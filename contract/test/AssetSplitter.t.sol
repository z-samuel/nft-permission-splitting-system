// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import "../src/AssetNFT.sol";
import "../src/SyntheticNFT.sol";
import "../src/AssetSplitter.sol";

contract AssetSplitterTest is Test {
    AssetNFT assetNFT;
    SyntheticNFT syntheticNFT;
    AssetSplitter assetSplitter;

    address alice = address(1);
    address bob = address(2);
    address sam = address(3);

    uint256 constant PERMISSION_A = 1;
    uint256 constant PERMISSION_B = 2;
    uint256 constant PERMISSION_C = 4;
    uint256 constant FULL_PERMISSIONS = 7;

    function setUp() public {
        assetNFT = new AssetNFT();
        syntheticNFT = new SyntheticNFT();
        assetSplitter = new AssetSplitter(address(assetNFT), address(syntheticNFT));
        assetNFT.transferOwnership(address(assetSplitter));
        syntheticNFT.transferOwnership(address(assetSplitter));

        vm.prank(alice);
        uint256 assetId = assetNFT.mint();
        vm.prank(alice);
        assetNFT.transferFrom(alice, bob, assetId); // Transfer ownership to bob for testing
    }

    // --- Test Cases for splitAsset ---

    function testSplitAsset_SuccessWithRemainder() public {
        uint256 assetId = 1;
        uint256 startTime = block.timestamp + 30 days;
        uint256 endTime = startTime + 60 days;

        IAssetSplitter.PermissionSet[] memory permissionSets = new IAssetSplitter.PermissionSet[](1);
        permissionSets[0] = IAssetSplitter.PermissionSet(PERMISSION_A, startTime, endTime);

        vm.prank(bob);
        uint256[] memory syntheticIds = assetSplitter.splitAsset(assetId, permissionSets);

        assertEq(syntheticIds.length, 4, "Should have created 4 Synthetic NFTs (one before startTime, one for A, one for remainder, one after endTime)");
        assertTrue(syntheticNFT.ownerOf(syntheticIds[0]) == bob, "Synthetic NFT 0 owner should be bob");
        assertTrue(syntheticNFT.ownerOf(syntheticIds[1]) == bob, "Synthetic NFT 1 owner should be bob");
        assertTrue(syntheticNFT.ownerOf(syntheticIds[2]) == bob, "Synthetic NFT 2 owner should be bob");
        assertTrue(syntheticNFT.ownerOf(syntheticIds[3]) == bob, "Synthetic NFT 3 owner should be bob");

        // Synthetic NFT before startTime
        (uint256 assetIdS, uint256 permissionsS, uint256 startTimeS, uint256 endTimeS) = syntheticNFT.syntheticNFTData(syntheticIds[0]);
        assertEq(assetIdS, assetId, "Synthetic NFT 0 Asset ID mismatch");
        assertEq(permissionsS, FULL_PERMISSIONS, "Synthetic NFT 0 Permissions mismatch");
        assertEq(startTimeS, 0, "Synthetic NFT 0 Start Time mismatch");
        assertEq(endTimeS, startTime, "Synthetic NFT 0 End Time mismatch");

        // Synthetic NFT for PERMISSION_A
        (uint256 assetIdA, uint256 permissionsA, uint256 startTimeA, uint256 endTimeA) = syntheticNFT.syntheticNFTData(syntheticIds[1]);
        assertEq(assetIdA, assetId, "Synthetic NFT 1 Asset ID mismatch");
        assertEq(permissionsA, PERMISSION_A, "Synthetic NFT 1 Permissions mismatch");
        assertEq(startTimeA, startTime, "Synthetic NFT 1 Start Time mismatch");
        assertEq(endTimeA, endTime, "Synthetic NFT 1 End Time mismatch");

        // Synthetic NFT for the remainder (PERMISSION_B | PERMISSION_C)
        (uint256 assetIdR, uint256 permissionsR, uint256 startTimeR, uint256 endTimeR) = syntheticNFT.syntheticNFTData(syntheticIds[2]);
        assertEq(assetIdR, assetId, "Synthetic NFT 2 Asset ID mismatch");
        assertEq(permissionsR, PERMISSION_B | PERMISSION_C, "Synthetic NFT 2 Permissions mismatch");
        assertEq(startTimeR, startTime, "Synthetic NFT 2 Start Time mismatch");
        assertEq(endTimeR, endTime, "Synthetic NFT 2 End Time mismatch");

        // Synthetic NFT after endTime
        (uint256 assetIdE, uint256 permissionsE, uint256 startTimeE, uint256 endTimeE) = syntheticNFT.syntheticNFTData(syntheticIds[3]);
        assertEq(assetIdE, assetId, "Synthetic NFT 3 Asset ID mismatch");
        assertEq(permissionsE, FULL_PERMISSIONS, "Synthetic NFT 3 Permissions mismatch");
        assertEq(startTimeE, endTime, "Synthetic NFT 3 Start Time mismatch");
        assertEq(endTimeE, 0, "Synthetic NFT 3 End Time mismatch");

        vm.expectRevert();
        assetNFT.ownerOf(assetId);
    }

    function testSplitAsset_SuccessNoRemainder() public {
        uint256 assetId = 1;

        IAssetSplitter.PermissionSet[] memory permissionSets = new IAssetSplitter.PermissionSet[](3);
        permissionSets[0] = IAssetSplitter.PermissionSet(PERMISSION_A, 0, 0);
        permissionSets[1] = IAssetSplitter.PermissionSet(PERMISSION_B, 0, 0);
        permissionSets[2] = IAssetSplitter.PermissionSet(PERMISSION_C, 0, 0);

        vm.prank(bob);
        uint256[] memory syntheticIds = assetSplitter.splitAsset(assetId, permissionSets);

        assertEq(syntheticIds.length, 10, "Should have created 10 Synthetic NFTs");

        (uint256 assetIdA, uint256 permissionsA, uint256 startTimeA, uint256 endTimeA) = syntheticNFT.syntheticNFTData(syntheticIds[0]);
        assertEq(assetIdA, assetId, "Synthetic NFT 0 Asset ID mismatch");
        assertEq(permissionsA, PERMISSION_A, "Synthetic NFT 0 Permissions mismatch");
        assertEq(startTimeA, 0, "Synthetic NFT 0 Start Time mismatch");
        assertEq(endTimeA, 0, "Synthetic NFT 0 End Time mismatch");

        (uint256 assetIdB, uint256 permissionsB, uint256 startTimeB, uint256 endTimeB) = syntheticNFT.syntheticNFTData(syntheticIds[1]);
        assertEq(assetIdB, assetId, "Synthetic NFT 1 Asset ID mismatch");
        assertEq(permissionsB, PERMISSION_B, "Synthetic NFT 1 Permissions mismatch");
        assertEq(startTimeB, 0, "Synthetic NFT 1 Start Time mismatch");
        assertEq(endTimeB, 0, "Synthetic NFT 1 End Time mismatch");

        (uint256 assetIdC, uint256 permissionsC, uint256 startTimeC, uint256 endTimeC) = syntheticNFT.syntheticNFTData(syntheticIds[2]);
        assertEq(assetIdC, assetId, "Synthetic NFT 2 Asset ID mismatch");
        assertEq(permissionsC, PERMISSION_C, "Synthetic NFT 2 Permissions mismatch");
        assertEq(startTimeC, 0, "Synthetic NFT 2 Start Time mismatch");
        assertEq(endTimeC, 0, "Synthetic NFT 2 End Time mismatch");

        vm.expectRevert();
        assetNFT.ownerOf(assetId);
        for (uint256 i = 3; i < 10; i++) {
            vm.expectRevert();
            assertEq(syntheticIds[3], 0, "There should be no more than 3 Synthetic NFTs");
        }
    }

    function testSplitAsset_SuccessMultipleRemainders() public {
        uint256 assetId = 1;
        uint256 startTime1 = block.timestamp + 30 days;
        uint256 endTime1 = startTime1 + 60 days;
        uint256 startTime2 = endTime1 + 90 days;
        uint256 endTime2 = startTime2 + 60 days;

        IAssetSplitter.PermissionSet[] memory permissionSets = new IAssetSplitter.PermissionSet[](2);
        permissionSets[0] = IAssetSplitter.PermissionSet(PERMISSION_A, startTime1, endTime1);
        permissionSets[1] = IAssetSplitter.PermissionSet(PERMISSION_B, startTime2, endTime2);

        vm.prank(bob);
        uint256[] memory syntheticIds = assetSplitter.splitAsset(assetId, permissionSets);

        assertEq(syntheticIds.length, 7, "Should have created four Synthetic NFTs (remainders before, between, and after)");
        vm.expectRevert();
        assetNFT.ownerOf(assetId);
    }

    function testSplitAsset_InvalidPermissionValue() public {
        uint256 assetId = 1;

        IAssetSplitter.PermissionSet[] memory permissionSets = new IAssetSplitter.PermissionSet[](1);
        permissionSets[0] = IAssetSplitter.PermissionSet(8, 0, 0); // Invalid permission value

        vm.prank(bob);
        vm.expectRevert("AssetSplitter: Invalid permission value");
        assetSplitter.splitAsset(assetId, permissionSets);
    }

    function testSplitAsset_NotAssetOwner() public {
        uint256 assetId = 1;

        IAssetSplitter.PermissionSet[] memory permissionSets = new IAssetSplitter.PermissionSet[](1);
        permissionSets[0] = IAssetSplitter.PermissionSet(FULL_PERMISSIONS, 0, 0);

        vm.prank(alice); // Alice is not the owner
        vm.expectRevert("AssetSplitter: Only asset owner can split");
        assetSplitter.splitAsset(assetId, permissionSets);
    }

    // --- Test Cases for mergeAsset ---

    function testMergeAsset_Success() public {
        uint256 assetId = 1;
        uint256 startTime = block.timestamp + 30 days;
        uint256 endTime = startTime + 60 days;

        vm.prank(bob);
        IAssetSplitter.PermissionSet[] memory permissionSets = new IAssetSplitter.PermissionSet[](1);
        permissionSets[0] = IAssetSplitter.PermissionSet(PERMISSION_A, startTime, endTime);

        uint256[] memory syntheticIds = assetSplitter.splitAsset(assetId, permissionSets);
        assertEq(syntheticIds.length, 4, "Should have created 4 Synthetic NFTs");

        vm.prank(bob);
        uint256 newAssetId = assetSplitter.mergeAsset(assetId, syntheticIds);

        assertEq(assetNFT.ownerOf(newAssetId), bob, "New Asset NFT owner should be bob");
        for (uint256 i = 0; i < 4; i++) {
            vm.expectRevert();
            syntheticNFT.ownerOf(syntheticIds[i]);
        }
    }

    function testMergeAsset_NotAssetOwner() public {
        uint256 assetId = 1;
        uint256 startTime = block.timestamp + 30 days;
        uint256 endTime = startTime + 60 days;

        IAssetSplitter.PermissionSet[] memory permissionSets = new IAssetSplitter.PermissionSet[](1);
        permissionSets[0] = IAssetSplitter.PermissionSet(PERMISSION_A, startTime, endTime);

        vm.prank(bob);
        uint256[] memory syntheticIds = assetSplitter.splitAsset(assetId, permissionSets);

        vm.prank(alice);
        vm.expectRevert("AssetSplitter: Only asset owner can merge");
        assetSplitter.mergeAsset(assetId, syntheticIds);
    }

    function testMergeAsset_NotOwnerOfSynthetic() public {
        uint256 assetId = 1;
        uint256 startTime = block.timestamp + 30 days;
        uint256 endTime = startTime + 60 days;

        IAssetSplitter.PermissionSet[] memory permissionSets = new IAssetSplitter.PermissionSet[](1);
        permissionSets[0] = IAssetSplitter.PermissionSet(PERMISSION_A, startTime, endTime);

        vm.prank(bob);
        uint256[] memory syntheticIds = assetSplitter.splitAsset(assetId, permissionSets);

        vm.prank(sam);
        vm.expectRevert("AssetSplitter: Only asset owner can merge");
        assetSplitter.mergeAsset(assetId, syntheticIds);
    }

    function testMergeAsset_NotFullPermissions() public {
        uint256 assetId = 1;

        IAssetSplitter.PermissionSet[] memory permissionSets = new IAssetSplitter.PermissionSet[](1);
        permissionSets[0] = IAssetSplitter.PermissionSet(PERMISSION_A, 0, 0);

        vm.prank(bob);
        uint256[] memory syntheticIds = assetSplitter.splitAsset(assetId, permissionSets);
        uint256[] memory subsetIds = new uint256[](1);
        subsetIds[0] = syntheticIds[0];

        vm.prank(bob);
        vm.expectRevert("AssetSplitter: Synthetic NFTs do not represent the full set of permissions");
        assetSplitter.mergeAsset(assetId, subsetIds);
    }

    function testMergeAsset_IncompletedTimeRanges() public {
        uint256 assetId = 1;
        uint256 startTime1 = block.timestamp + 30 days;
        uint256 endTime1 = startTime1 + 60 days;
        uint256 startTime2 = block.timestamp + 90 days;
        uint256 endTime2 = startTime2 + 120 days;

        IAssetSplitter.PermissionSet[] memory permissionSets = new IAssetSplitter.PermissionSet[](2);
        permissionSets[0] = IAssetSplitter.PermissionSet(PERMISSION_A, startTime1, endTime1);
        permissionSets[1] = IAssetSplitter.PermissionSet(PERMISSION_B, startTime2, endTime2);

        vm.prank(bob);
        uint256[] memory syntheticIds = assetSplitter.splitAsset(assetId, permissionSets);
        uint256[] memory subsetIds = new uint256[](5);
        subsetIds[0] = syntheticIds[0];
        subsetIds[1] = syntheticIds[1];
        subsetIds[2] = syntheticIds[2];
        subsetIds[3] = syntheticIds[4];
        subsetIds[4] = syntheticIds[5];

        vm.prank(bob);
        vm.expectRevert("AssetSplitter: Time range have incompleted permission");
        assetSplitter.mergeAsset(assetId, subsetIds);
    }

    function testMergeAsset_SameTimeRange() public {
        uint256 assetId = 1;
        uint256 startTime = block.timestamp + 30 days;
        uint256 endTime = startTime + 60 days;

        IAssetSplitter.PermissionSet[] memory permissionSets = new IAssetSplitter.PermissionSet[](2);
        permissionSets[0] = IAssetSplitter.PermissionSet(PERMISSION_A, startTime, endTime);
        permissionSets[1] = IAssetSplitter.PermissionSet(PERMISSION_B, startTime, endTime);

        vm.prank(bob);
        uint256[] memory syntheticIds = assetSplitter.splitAsset(assetId, permissionSets);

        vm.prank(bob);
        uint256 newAssetId = assetSplitter.mergeAsset(assetId, syntheticIds);

        assertEq(assetNFT.ownerOf(newAssetId), bob, "New Asset NFT owner should be bob");
        vm.expectRevert();
        syntheticNFT.ownerOf(syntheticIds[0]);
        vm.expectRevert();
        syntheticNFT.ownerOf(syntheticIds[1]);
    }
}