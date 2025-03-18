// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/AssetNFT.sol";
import "../src/SyntheticNFT.sol";
import "../src/AssetSplitter.sol";

contract DeployContracts is Script {
    function run() external {
        vm.startBroadcast();

        AssetNFT assetNFT = new AssetNFT();
        console.log("AssetNFT deployed to:", address(assetNFT));

        SyntheticNFT syntheticNFT = new SyntheticNFT();
        console.log("SyntheticNFT deployed to:", address(syntheticNFT));

        AssetSplitter assetSplitter = new AssetSplitter(address(assetNFT), address(syntheticNFT));
        console.log("AssetSplitter deployed to:", address(assetSplitter));

        // Transfer ownership of SyntheticNFT to AssetSplitter
        SyntheticNFT(address(syntheticNFT)).transferOwnership(address(assetSplitter));
        console.log("Ownership of SyntheticNFT transferred to AssetSplitter");

        // Transfer ownership of AssetNFT to AssetSplitter
        AssetNFT(address(assetNFT)).transferOwnership(address(assetSplitter));
        console.log("Ownership of AssetNFT transferred to AssetSplitter");

        vm.stopBroadcast();
    }
}