// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBTokens.sol';
import '@jbx-protocol/juice-721-delegate/contracts/interfaces/IJBTiered721DelegateStore.sol';
import '../DefifaDeployer.sol';
import '../DefifaGovernor.sol';
import 'forge-std/Script.sol';

contract DeployMainnet is Script {
  function run() external {
    vm.startBroadcast();

    // V3 goerli controller.
    IJBController controller = IJBController(0xFFdD70C318915879d5192e8a0dcbFcB0285b3C98);
    // goerli 721 store.
    IJBTiered721DelegateStore store = IJBTiered721DelegateStore(
      0xffB2Cd8519439A7ddcf2C933caedd938053067D2
    );
    // V3 goerli Payment terminal.
    IJBPaymentTerminal terminal = IJBPaymentTerminal(0x594Cb208b5BB48db1bcbC9354d1694998864ec63);

    address _defifaBallcats = 0x11834239698c7336EF232C00a2A9926d3375DF9D;
    // Game params.
    uint48 _start = 1669024800; // 2am PST, Nov 21.
    uint48 _mintDuration = 1209600; // 2 weeks.
    uint48 _tradeDeadline = 1670598000; // 7am, Dec 9.
    uint48 _end = 1671375600 + 604800; // 7 days after the finals. Dec 25, 7am PST.

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
    _delegateData.owner = computeCreateAddress(tx.origin, vm.getNonce(tx.origin) + 1);

    // Launch the game - initialNonce
    uint256 _projectId = defifaDeployer.launchGameWith(_delegateData, _launchProjectData);
    // initialNonce + 1

    // Get a reference to the latest configured funding cycle's data source, which should be the delegate that was deployed and attached to the project.
    (, JBFundingCycleMetadata memory _metadata, ) = controller.latestConfiguredFundingCycleOf(
      _projectId
    );
    // initialNonce + 1 (view function)

    // Deploy the governor
    {
      address _governor = address(new DefifaGovernor(DefifaDelegate(_metadata.dataSource), _end));
      
      // These 3 should be the same:
      console.log(_delegateData.owner);
      console.log(_governor);
      console.log(Ownable(_metadata.dataSource).owner());
    }

    console.log(address(defifaDeployer));
    console.log(address(store));
    console.log(_metadata.dataSource);
  }
}

contract DeployGoerli is Script {
  function run() external {
    vm.startBroadcast();

    // V3 goerli controller.
    IJBController controller = IJBController(0x7Cb86D43B665196BC719b6974D320bf674AFb395);
    // goerli 721 store.
    IJBTiered721DelegateStore store = IJBTiered721DelegateStore(
      0x3EA16DeFF07f031e86bd13C55961eB576cd579a6
    );
    // V3 goerli Payment terminal.
    IJBPaymentTerminal terminal = IJBPaymentTerminal(0x55d4dfb578daA4d60380995ffF7a706471d7c719);

    address _defifaBallcats = 0x11834239698c7336EF232C00a2A9926d3375DF9D;
    // Game params.
    uint48 _start = 1667968400; // 1pm PST, Nov 6.
    uint48 _mintDuration = 7200; // 2 hours.
    uint48 _tradeDeadline = 1667968400 + 7200; // 2 hours after start.
    uint48 _end = 1667968400 + 7200 + 7200; // 2 hours after trade deadline.

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
    _delegateData.owner = computeCreateAddress(tx.origin, vm.getNonce(tx.origin) + 1);

    // Launch the game - initialNonce
    uint256 _projectId = defifaDeployer.launchGameWith(_delegateData, _launchProjectData);
    // initialNonce + 1

    // Get a reference to the latest configured funding cycle's data source, which should be the delegate that was deployed and attached to the project.
    (, JBFundingCycleMetadata memory _metadata, ) = controller.latestConfiguredFundingCycleOf(
      _projectId
    );
    // initialNonce + 1 (view function)

    // Deploy the governor
    {
      address _governor = address(new DefifaGovernor(DefifaDelegate(_metadata.dataSource), _end));
      
      // These 3 should be the same:
      console.log(_delegateData.owner);
      console.log(_governor);
      console.log(Ownable(_metadata.dataSource).owner());
    }

    console.log(address(defifaDeployer));
    console.log(address(store));
    console.log(_metadata.dataSource);
  }
}
