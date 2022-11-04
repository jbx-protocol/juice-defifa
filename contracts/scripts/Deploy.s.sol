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

  function run() external {
    vm.startBroadcast();

    // V3 goerli controller.
    IJBController controller = IJBController(0x7Cb86D43B665196BC719b6974D320bf674AFb395);
    // goerli 721 store.
    IJBTiered721DelegateStore store =
      IJBTiered721DelegateStore(0x3EA16DeFF07f031e86bd13C55961eB576cd579a6);
    // V3 goerli Payment terminal.
    IJBPaymentTerminal terminal = IJBPaymentTerminal(0x55d4dfb578daA4d60380995ffF7a706471d7c719);

    address _defifaBallcats = 0x11834239698c7336EF232C00a2A9926d3375DF9D; 
    // Game params.
    uint48 _mintDuration = 14400; // 4 hrs
    uint48 _start = 1667599200 + 14400; // 4 hrs after 3pm PST Nov 4
    uint48 _tradeDeadline = 1667599200 + 14400 + 10800; // 3 hours after start.
    uint48 _end = 1667599200 + 14400 + 10800 + 10800; // 3 hours after trade deadline.

    JB721TierParams[] memory _tiers = new JB721TierParams[](32);

    bytes32[] memory _teamEncodedIPFSUris = new bytes32[](32);
    _teamEncodedIPFSUris[0] = 0xb2cf9b27f33b6b445b31fa13ad93600d35a1bafd27543b313af1e2cd727e213b;
    _teamEncodedIPFSUris[1] = 0xbfabff3f158961179837886c91f9e5847a25865b20f1a3c4f13448323284d31f;
    _teamEncodedIPFSUris[2] = 0xf526000358a2bb0227db6a0f4c28b8cfb242e0a16f568975b6f7839ef2075761;
    _teamEncodedIPFSUris[3] = 0xb514ff48aef786b83f456773af2b432365707b84ca9ec02c0639732279c57f35;
    _teamEncodedIPFSUris[4] = 0x816bff580d5d900165c09b953c11cd4a9fe15b41ded825edfc82680eb7cdeaa9;
    _teamEncodedIPFSUris[5] = 0x2850e2b55a3fb53a17173d0e91938e2da2d520c3092858ce68a460dad35bbc91;
    _teamEncodedIPFSUris[6] = 0x98fa3187e98ad21fcdf43a1e1601e8f8619ceeaf9f3fb0039f2f61f31e35a145;
    _teamEncodedIPFSUris[7] = 0xda36dfe50c30ae4e83b4e8ef4cd4ce9e580298a55d31b8d7276e644380ce9ff6;
    _teamEncodedIPFSUris[8] = 0x8b3b961de3bacb600488d91dbe9277c50f16311b92455e82ce6c26d078d9503f;
    _teamEncodedIPFSUris[9] = 0x0977f77350659d1f8284f1b0a4f0ee447cf32c6ef8c06b7ec5f9295822818111;
    _teamEncodedIPFSUris[10] = 0x6198d84d8904f2c89fa6ff3de01ccce8b928cfb6182da65723b70aa1e63a94c8;
    _teamEncodedIPFSUris[11] = 0x895646f615fc45358d894014f3d8c15ad020323cf57c6624464bd11a2815a480;
    _teamEncodedIPFSUris[12] = 0x6388190babc4fd7ad390b545dc0eaf01222355583ce0a5d5496c2bb6f118039b;
    _teamEncodedIPFSUris[13] = 0x33e06853378f58d42ceb8ab266d25656eded385f82a777ca563c5e38d5241a83;
    _teamEncodedIPFSUris[14] = 0x2f4275c8dac582d4718d41315e8406e502f9edc24718508008c9be2120c29718;
    _teamEncodedIPFSUris[15] = 0x6ff53e06711936e10bd3ca5786ca9c47cbd42f5b878289c350fa405513cbba39;
    _teamEncodedIPFSUris[16] = 0xdaae0d745afe8943fffe0a733b7da605db462162bf0895d069daf8137ded8b0f;
    _teamEncodedIPFSUris[17] = 0xba245717d6e4293217d7e94f19b5aef1a84f6902bced1332eb8607aaddd43db2;
    _teamEncodedIPFSUris[18] = 0x42a65ae98f0d43856f8d75d645dbe964750f42415e038264813c95e1fd977839;
    _teamEncodedIPFSUris[19] = 0x755651ad1de6c43ed4525d761a39c4521445f67c72010544cdbe156928954d2d;
    _teamEncodedIPFSUris[20] = 0x6f880ca3d58e8f48a8709d097ead5dda0969f525efacadba9d707fd68578e45f;
    _teamEncodedIPFSUris[21] = 0x9ca1e5354a134ff50d36121ccc511ac6a1c42797512aceea4d1e14811359c063;
    _teamEncodedIPFSUris[22] = 0x91b2e30c3f239b25f75ea44ca36ddaa616738bd88ecedd67691f22bffe401727;
    _teamEncodedIPFSUris[23] = 0xdfb13aa5ab8c607ca1772385ece7dc4213a06ae0e7a09058592556e19b4ef6eb;
    _teamEncodedIPFSUris[24] = 0xb587a257c1a625c9b28f3f2c841fe99fdad97d111f94a3f238e1a8f224b48e37;
    _teamEncodedIPFSUris[25] = 0xab1d428c4b2594b8232abff414ad259f6748dbe13302dd7d4758c12a79b9ffbf;
    _teamEncodedIPFSUris[26] = 0x5756ead1507fa2210f66dd2bf9ed722b27929ccd90fade1a234447dc01cc8ef0;
    _teamEncodedIPFSUris[27] = 0x032083c1a27f9e5fed3236e357dca8e7bc205681a9942465adfeca40efcc05a5;
    _teamEncodedIPFSUris[28] = 0x60c52313561051352c1d98d9652815b555f95c0ee250b9afd1acddf95dec9578;
    _teamEncodedIPFSUris[29] = 0x5b88630af3d5ad16f18c2c8528a41b925233c61e40c8934d7981e21881b062b5;
    _teamEncodedIPFSUris[30] = 0x1ba892a008a164359a2b70ef1ab046d90fa3af4ce4815c00cd07a2a9237e9808;
    _teamEncodedIPFSUris[31] = 0x193bb548bbf52cf76e00185e24c0eada8f758dfef1927cfaa202207e4beb6cec;

    for (uint256 _i; _i < 32; ) {
      _tiers[_i] = JB721TierParams({
        contributionFloor: 0.022 ether,
        lockedUntil: 0,
        initialQuantity: 1_000_000_000 - 1, // max
        votingUnits: 1,
        reservedRate: 9,
        reservedTokenBeneficiary: _defifaBallcats,
        encodedIPFSUri: _teamEncodedIPFSUris[_i],
        allowManualMint: false,
        shouldUseBeneficiaryAsDefault: true,
        transfersPausable: true
      });

      unchecked {
        ++_i;
      }
    }

    DefifaDelegateData memory _delegateData = DefifaDelegateData({
      name: 'Defifa: FIFA World Cup 2022',
      symbol: 'DEFIFA',
      baseUri: 'ipfs://',
      contractUri: 'QmaK1Hib3Umokija4bRwoPdxHgGY3unRreeeLoJss3vw4Y',
      tiers: _tiers,
      store: store,
      // Set owner will be set to the Governor later on in this script.
      owner: address(0)
    });

    DefifaLaunchProjectData memory _launchProjectData = DefifaLaunchProjectData({
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

    // Deploy the codeOrigin for the delegate
    DefifaDelegate _defifaDelegateCodeOrigin = new DefifaDelegate();

    // Deploy the deployer.
    DefifaDeployer defifaDeployer = new DefifaDeployer(
      address(_defifaDelegateCodeOrigin),
      controller,
      JBTokens.ETH,
      _defifaBallcats
    );

    // Set the owner as the governor (done here to easily count future nonces)
    _delegateData.owner = computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
    console.log(_delegateData.owner);

    // Launch the game - initialNonce
    uint256 _projectId = defifaDeployer.launchGameWith(_delegateData, _launchProjectData);
    // initialNonce + 1

    // Get a reference to the latest configured funding cycle's data source, which should be the delegate that was deployed and attached to the project.
    (, JBFundingCycleMetadata memory _metadata, ) = controller.latestConfiguredFundingCycleOf(
      _projectId
    );
    // initialNonce + 1 (view function)

    // Deploy the governor
    new DefifaGovernor(DefifaDelegate(_metadata.dataSource), _end);

    console.log(address(defifaDeployer));
    console.log(address(store));
  }
}
