// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBTokens.sol';
import '@jbx-protocol/juice-721-delegate/contracts/interfaces/IJBTiered721DelegateStore.sol';
import '../DefifaDeployer.sol';
import '../DefifaGovernor.sol';
import 'forge-std/Script.sol';

/// tier bs58 encoded hashs
// b91344f4773f993f7a07b2e7c21144efbc08d6986064e6fae32cf9e39213c5b1
// 1ff521b56939b46eab321e9267e6e63b1d4924274b443a7581bb130c3da5efc2
// fbb8fa70b8d94803dbed55eabd9dbceff13753d1edae148ed155788cfe492062
// b5b38f73b1216590fc226b310f8c471568941f2d7ba723db645eea3761cbe31f
// b7ff07c99801e49ed828aa616536cb524518fabe2137321279e36049678a363a
// 917a30091f0d5428fe0406b0cd15596926b6e11001281bddee9f6f73cb80e141
// 4f3ed02b37a1ffec0f44202c61e6d967b85be7fb932698d96a8144a7a7749fe6
// 2db337edb9a4e035f3bbbe483a8d33387ccf6e9b6c45e4042ac410cc8c28fd37
// d3ab4d1e431360888e5741a0de4d3e10fb6f4b6c0e102dcc4f9a2abb5fe36de6
// 77d4e416732fd54c3d46acc9b1590833688c04e259219a9b1356367d27271120
// 00822683fbe03bfbc616ac4e0afbcfab8b4f083799aca9991051ecdf966f676f
// 7492595e25f4af84ffb7c5429fe1f0bdc73713d7ac5dddec1f50719e24b9193c
// 909b7b26f87f6f850659df109651f9d574ba0b6b59f86a0ced52db9a6627b0b3
// fee0ab09da89693658aca5ef4d4d6dcad884eabcc369ad8d04f7e8ad3bce827b
// 1cf9fc5dfa7cde9bed1cc7baf4e425fd583cc994cf55dc787548f9ff2ab2a10d
// 67eda83f9da2ba7445be670369f422bfff57810ae4df1e2f100741a05823114f
// 3eac96d97f093d6ee6f8f96b1a56f44fce4f27414dd2ced028d58fcbd3a53672
// 0042739099ab8b1e7fce63f9726c50e1e1a8010898ca610b9d47c949dd8ec91d
// e4aca1b585eef873d35d20954901d30fa512289670f3a0d75f6069f1bb3050da
// 410eb824734c4d1a2af392a556e193b2cedaaa46b9b947c5a5bce4f56f7203e5
// c8830bbef64df1db9be751819caf84a9045fa7c9d2c24bbbf1e602dfd4a9a604
// 6c3bb9b9eca78329b57913b50d8909ef7cbcc027b07a59cce0b93cd3322aee30
// e438229473fd6e388b00c2ddc38bc26f305c82e810f4d4f57882f5d0fc19ae02
// 63a10817d846097ff3deb2629478f84337e061c4ce7f5f6cf42b47a7fdf2cf81
// 280ca3dc988d128bf9dcc65d48e7618fb8afc19cc4b37670e37fc701d7ac80e1
// 73b1312b13d391eb831d36061c9ef22b391d972f89c61a0bbe0c059c315c9240
// 34699c833931de2e2e8cfbc4c5c10dad1d2cc33c68566e445c0a328d5e8e8a01
// 398b33b6410606dd006644ee9d2feea8ac879d9e5d4afb8b43aed1fa3e0d6629
// af983fe78649e2e9cb5d5748d8ccd3d079252c69478145bfe097f4cb1907eba9
// 2625b95ad078da07bf45efbd615df4b4555c146c8b4f7ff75242d211cfa0883d
// 7b0e6bb3e54c32f5ed1f2b1676e3a6ff2e50eea945895cbaf825ad609fc43b8e
// c1a79e518b8a08cecee7463180fe2524a8cad019c4604bcd5dc4bb089c563780

// contract DeployMainnet is Script {
//     IJBController jbController = IJBController(0xFFdD70C318915879d5192e8a0dcbFcB0285b3C98);
//     IJBOperatorStore jbOperatorStore = IJBOperatorStore(0x6F3C5afCa0c9eDf3926eF2dDF17c8ae6391afEfb);
//     JBTiered721DelegateDeployer delegateDeployer;
//     JBTiered721DelegateProjectDeployer projectDeployer;
//     JBTiered721DelegateStore store;
//     function run() external {
//       vm.startBroadcast();
//       JBTiered721Delegate noGovernance = new JBTiered721Delegate();
//       JB721GlobalGovernance globalGovernance = new JB721GlobalGovernance();
//       JB721TieredGovernance tieredGovernance = new JB721TieredGovernance();
//       delegateDeployer = new JBTiered721DelegateDeployer(
//         globalGovernance,
//         tieredGovernance,
//         noGovernance
//       );
//       store = new JBTiered721DelegateStore();
//       projectDeployer = new JBTiered721DelegateProjectDeployer(
//         jbController,
//         delegateDeployer,
//         jbOperatorStore
//       );
//       console.log(address(projectDeployer));
//       console.log(address(store));
//     }
//   }
contract DeployGoerli is Script {
  // V3 goerli controller.
  IJBController controller = IJBController(0x7Cb86D43B665196BC719b6974D320bf674AFb395);
  // goerli 721 store.
  IJBTiered721DelegateStore store = IJBTiered721DelegateStore(0x32bb71C6DbD6A1b3A37394565872D0eB7fF3846D);
  // V3 goerli Payment terminal.
  IJBPaymentTerminal terminal = IJBPaymentTerminal(0x55d4dfb578daA4d60380995ffF7a706471d7c719);

  // Game params.
  uint48 _mintDuration =  86400; // 24 hrs
  uint48 _start = 1667538000 + 86400;  // 24 hrs after 10pm PST
  uint48 _tradeDeadline = 1667538000 + 86400 + 10800; // 3 hours after start.
  uint48 _end = 1667538000 + 86400 + 10800 + 10800; // 3 hours after trade deadline.

  function run() external {
    vm.startBroadcast();

    JB721TierParams[] memory _tiers = new JB721TierParams[](32);

    bytes32[] memory _teamEncodedIPFSUris = new bytes32[](32);
    _teamEncodedIPFSUris[0] = 0xb91344f4773f993f7a07b2e7c21144efbc08d6986064e6fae32cf9e39213c5b1;
    _teamEncodedIPFSUris[1] = 0x1ff521b56939b46eab321e9267e6e63b1d4924274b443a7581bb130c3da5efc2;
    _teamEncodedIPFSUris[2] = 0xfbb8fa70b8d94803dbed55eabd9dbceff13753d1edae148ed155788cfe492062;
    _teamEncodedIPFSUris[3] = 0xb5b38f73b1216590fc226b310f8c471568941f2d7ba723db645eea3761cbe31f;
    _teamEncodedIPFSUris[4] = 0xb7ff07c99801e49ed828aa616536cb524518fabe2137321279e36049678a363a;
    _teamEncodedIPFSUris[5] = 0x917a30091f0d5428fe0406b0cd15596926b6e11001281bddee9f6f73cb80e141;
    _teamEncodedIPFSUris[6] = 0x4f3ed02b37a1ffec0f44202c61e6d967b85be7fb932698d96a8144a7a7749fe6;
    _teamEncodedIPFSUris[7] = 0x2db337edb9a4e035f3bbbe483a8d33387ccf6e9b6c45e4042ac410cc8c28fd37;
    _teamEncodedIPFSUris[8] = 0xd3ab4d1e431360888e5741a0de4d3e10fb6f4b6c0e102dcc4f9a2abb5fe36de6;
    _teamEncodedIPFSUris[9] = 0x77d4e416732fd54c3d46acc9b1590833688c04e259219a9b1356367d27271120;
    _teamEncodedIPFSUris[10] = 0x00822683fbe03bfbc616ac4e0afbcfab8b4f083799aca9991051ecdf966f676f;
    _teamEncodedIPFSUris[11] = 0x7492595e25f4af84ffb7c5429fe1f0bdc73713d7ac5dddec1f50719e24b9193c;
    _teamEncodedIPFSUris[12] = 0x909b7b26f87f6f850659df109651f9d574ba0b6b59f86a0ced52db9a6627b0b3;
    _teamEncodedIPFSUris[13] = 0xfee0ab09da89693658aca5ef4d4d6dcad884eabcc369ad8d04f7e8ad3bce827b;
    _teamEncodedIPFSUris[14] = 0x1cf9fc5dfa7cde9bed1cc7baf4e425fd583cc994cf55dc787548f9ff2ab2a10d;
    _teamEncodedIPFSUris[15] = 0x67eda83f9da2ba7445be670369f422bfff57810ae4df1e2f100741a05823114f;
    _teamEncodedIPFSUris[16] = 0x3eac96d97f093d6ee6f8f96b1a56f44fce4f27414dd2ced028d58fcbd3a53672;
    _teamEncodedIPFSUris[17] = 0x0042739099ab8b1e7fce63f9726c50e1e1a8010898ca610b9d47c949dd8ec91d;
    _teamEncodedIPFSUris[18] = 0xe4aca1b585eef873d35d20954901d30fa512289670f3a0d75f6069f1bb3050da;
    _teamEncodedIPFSUris[19] = 0x410eb824734c4d1a2af392a556e193b2cedaaa46b9b947c5a5bce4f56f7203e5;
    _teamEncodedIPFSUris[20] = 0xc8830bbef64df1db9be751819caf84a9045fa7c9d2c24bbbf1e602dfd4a9a604;
    _teamEncodedIPFSUris[21] = 0x6c3bb9b9eca78329b57913b50d8909ef7cbcc027b07a59cce0b93cd3322aee30;
    _teamEncodedIPFSUris[22] = 0xe438229473fd6e388b00c2ddc38bc26f305c82e810f4d4f57882f5d0fc19ae02;
    _teamEncodedIPFSUris[23] = 0x63a10817d846097ff3deb2629478f84337e061c4ce7f5f6cf42b47a7fdf2cf81;
    _teamEncodedIPFSUris[24] = 0x280ca3dc988d128bf9dcc65d48e7618fb8afc19cc4b37670e37fc701d7ac80e1;
    _teamEncodedIPFSUris[25] = 0x73b1312b13d391eb831d36061c9ef22b391d972f89c61a0bbe0c059c315c9240;
    _teamEncodedIPFSUris[26] = 0x34699c833931de2e2e8cfbc4c5c10dad1d2cc33c68566e445c0a328d5e8e8a01;
    _teamEncodedIPFSUris[27] = 0x398b33b6410606dd006644ee9d2feea8ac879d9e5d4afb8b43aed1fa3e0d6629;
    _teamEncodedIPFSUris[28] = 0xaf983fe78649e2e9cb5d5748d8ccd3d079252c69478145bfe097f4cb1907eba9;
    _teamEncodedIPFSUris[29] = 0x2625b95ad078da07bf45efbd615df4b4555c146c8b4f7ff75242d211cfa0883d;
    _teamEncodedIPFSUris[30] = 0x7b0e6bb3e54c32f5ed1f2b1676e3a6ff2e50eea945895cbaf825ad609fc43b8e;
    _teamEncodedIPFSUris[31] = 0xc1a79e518b8a08cecee7463180fe2524a8cad019c4604bcd5dc4bb089c563780;

    for (uint256 _i; _i < 32; ) {
      _tiers[_i] = JB721TierParams({
        contributionFloor: 0.022 ether,
        lockedUntil: 0,
        initialQuantity: 1_000_000_000 - 1, // max 
        votingUnits: 1,
        reservedRate: 9,
        reservedTokenBeneficiary: address(0),
        encodedIPFSUri: _teamEncodedIPFSUris[_i],
        allowManualMint: false,
        shouldUseBeneficiaryAsDefault: true,
        transfersPausable: true
      });
    }

    DefifaDelegateData memory _delegateData =
      DefifaDelegateData({
        name: 'Defifa: FIFA World Cup 2022',
        symbol: 'DEFIFA',
        baseUri: 'ipfs://',
        contractUri: 'QmWhNUiJo4Q6iycxK7a2GGXxFRcVXnUrHv1dYm4ScvuitR',
        tiers: _tiers,
        store: store,
        // Set owner will be set to the Governor later on in this script.
        owner: address(0)
      });

    DefifaLaunchProjectData memory _launchProjectData =
      DefifaLaunchProjectData({
        projectMetadata: JBProjectMetadata({
          content: 'QmT7VFuF7cPMwMnqh3YruuYcRk2tKMb2xcXSbK2wV82Hdy',
          domain: 0
        }),
        mintDuration: _mintDuration,
        start: _start,
        tradeDeadline: _tradeDeadline,
        end: _end,
        holdFees: false,
        splits: new JBSplit[](0),
        distributionLimit: 0,
        terminal: terminal
      });

    // Deploy the deployer.
    DefifaDeployer defifaDeployer = new DefifaDeployer(controller, JBTokens.ETH);

    // Set the owner as the governor (done here to easily count future nonces)
    _delegateData.owner = computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
    console.log(_delegateData.owner);

    // Launch the game - initialNonce
    uint256 _projectId = defifaDeployer.launchGameWith(_delegateData, _launchProjectData);
    // initialNonce + 1

    // Get a reference to the latest configured funding cycle's data source, which should be the delegate that was deployed and attached to the project.
    (, JBFundingCycleMetadata memory _metadata,) = controller.latestConfiguredFundingCycleOf(_projectId);
    // initialNonce + 1 (view function)

    // Deploy the governor
    new DefifaGovernor(DefifaDelegate(_metadata.dataSource), _end);

    console.log(address(defifaDeployer));
    console.log(address(store));
  }


}