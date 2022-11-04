// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

// import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBTokens.sol';
// import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBOperations.sol';
// import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBOperatorData.sol';
// import '@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBOperatable.sol';

// import '@jbx-protocol/juice-721-delegate/contracts/interfaces/IJBTiered721DelegateStore.sol';

// import '../DefifaDeployer.sol';
// import '../DefifaGovernor.sol';
// import 'forge-std/Test.sol';

// // contract DeployMainnet is Script {
// //     IJBController jbController = IJBController(0xFFdD70C318915879d5192e8a0dcbFcB0285b3C98);
// //     IJBOperatorStore jbOperatorStore = IJBOperatorStore(0x6F3C5afCa0c9eDf3926eF2dDF17c8ae6391afEfb);
// //     JBTiered721DelegateDeployer delegateDeployer;
// //     JBTiered721DelegateProjectDeployer projectDeployer;
// //     JBTiered721DelegateStore store;
// //     function run() external {
// //       vm.startBroadcast();
// //       JBTiered721Delegate noGovernance = new JBTiered721Delegate();
// //       JB721GlobalGovernance globalGovernance = new JB721GlobalGovernance();
// //       JB721TieredGovernance tieredGovernance = new JB721TieredGovernance();
// //       delegateDeployer = new JBTiered721DelegateDeployer(
// //         globalGovernance,
// //         tieredGovernance,
// //         noGovernance
// //       );
// //       store = new JBTiered721DelegateStore();
// //       projectDeployer = new JBTiered721DelegateProjectDeployer(
// //         jbController,
// //         delegateDeployer,
// //         jbOperatorStore
// //       );
// //       console.log(address(projectDeployer));
// //       console.log(address(store));
// //     }
// //   }
// contract DeployGoerli is Test {
//   // V3 goerli controller.
//   IJBController controller = IJBController(0x7Cb86D43B665196BC719b6974D320bf674AFb395);
//   // goerli 721 store.
//   IJBTiered721DelegateStore store = IJBTiered721DelegateStore(0x32bb71C6DbD6A1b3A37394565872D0eB7fF3846D);
//   // V3 goerli Payment terminal.
//   IJBPaymentTerminal terminal = IJBPaymentTerminal(0x55d4dfb578daA4d60380995ffF7a706471d7c719);

//   DefifaDeployer defifaDeployer;
//   DefifaGovernor defifaGovernor;

//   // Tier standard params.
//   uint80 _contributionFloor = 0.022 ether;
//   uint40 _maxInitialQuantity = 1_000_000_000 - 1;
//   uint16 _votingUnits = 1;

//   // Game params.
//   uint256 _mustStartAtOrAfter = 0;
//   uint48 _mintDuration =  0;
//   uint48 _start = 0;
//   uint48 _tradeDeadline = 0;
//   uint48 _end = 0;

//   function test_deployGoerli() external {
//     //vm.startBroadcast();

//     JB721TierParams[] memory _tiers = new JB721TierParams[](1);
//     _tiers[0] = JB721TierParams({
//       contributionFloor: _contributionFloor,
//       lockedUntil: 0,
//       initialQuantity: _maxInitialQuantity,
//       votingUnits: _votingUnits,
//       reservedRate: 0,
//       reservedTokenBeneficiary: address(0),
//       encodedIPFSUri: bytes32(''),
//       allowManualMint: false,
//       shouldUseBeneficiaryAsDefault: true,
//       transfersPausable: true
//     });

//     DefifaDelegateData memory _delegateData =
//       DefifaDelegateData({
//         name: 'Defifa: FIFA World Cup 2022',
//         symbol: 'DEFIFA',
//         // TODO: Need a base URI.
//         baseUri: '',
//         // TODO: Need a contract URI.
//         contractUri: '',
//         tiers: _tiers,
//         store: store,
//         // TODO: set owner as the Governor that is being deployed.
//         owner: address(0)
//       });

//     DefifaLaunchProjectData memory _launchProjectData =
//       DefifaLaunchProjectData({
//         projectMetadata: JBProjectMetadata({
//           content: '',
//           domain: 0
//         }),
//         mustStartAtOrAfter: _mustStartAtOrAfter,
//         mintDuration: _mintDuration,
//         start: _start,
//         tradeDeadline: _tradeDeadline,
//         end: _end,
//         holdFees: false,
//         splits: new JBSplit[](0),
//         distributionLimit: 0,
//         terminal: terminal
//       });

//     // Deploy the codeOrigin for the delegate
//     DefifaDelegate _defifaDelegateCodeOrigin = new DefifaDelegate();

//     // Deploy the deployer.
//     defifaDeployer = new DefifaDeployer(address(_defifaDelegateCodeOrigin), controller, JBTokens.ETH);

//     uint256[] memory _permissionIndexes = new uint256[](1);
//     _permissionIndexes[0] = JBOperations.SET_SPLITS;

//     vm.startPrank(0x46D623731E179FAF971CdA04fF8c499C95461b3c);
//     IJBOperatable(address(terminal)).operatorStore().setOperator(JBOperatorData({operator: address(defifaDeployer), domain: 1, permissionIndexes: _permissionIndexes}));
//     vm.stopPrank();

//     // Set the owner as the governor (done here to easily count future nonces)
//     _delegateData.owner = computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
//     console.log(_delegateData.owner);

//     // Launch the game - initialNonce
//     uint256 _projectId = defifaDeployer.launchGameWith(_delegateData, _launchProjectData);
//     // initialNonce + 1

//     // Get a reference to the latest configured funding cycle's data source, which should be the delegate that was deployed and attached to the project.
//     (, JBFundingCycleMetadata memory _metadata,) = controller.latestConfiguredFundingCycleOf(_projectId);
//     // initialNonce + 1 (view function)

//     // Deploy the governor
//     defifaGovernor = new DefifaGovernor(DefifaDelegate(_metadata.dataSource), 0);

//     console.log(address(defifaDeployer));
//     console.log(address(store));
//   }

// }
