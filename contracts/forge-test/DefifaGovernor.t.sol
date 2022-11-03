// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import 'forge-std/Test.sol';
import '../DefifaGovernor.sol';
import '../DefifaDeployer.sol';
import '../DefifaDelegate.sol';

import '@jbx-protocol/juice-721-delegate/contracts/forge-test/utils/TestBaseWorkflow.sol';
import '@jbx-protocol/juice-721-delegate/contracts/structs/JBDeployTiered721DelegateData.sol';
import '@jbx-protocol/juice-721-delegate/contracts/structs/JBLaunchProjectData.sol';
import '@jbx-protocol/juice-721-delegate/contracts/JBTiered721DelegateStore.sol';

contract DefifaGovernorTest is TestBaseWorkflow {

  address projectOwner = address(bytes20(keccak256('projectOwner')));

  function setUp() public virtual override {
    super.setUp();
  }

  function testReceiveVotingPower(uint8 nTiers, uint8 tier) public {
    vm.assume(nTiers < 100);
    vm.assume(nTiers >= tier);
    vm.assume(tier != 0);

    address _user = address(bytes20(keccak256('user')));

    (
      uint256 _projectId,
      DefifaDelegate _nft,
      DefifaGovernor _governor
    ) = createDefifaProject(uint256(nTiers));

   // User should have no voting power (yet)
    assertEq(_governor.getVotes(_user, block.number - 1), 0);

    // fund user
    vm.deal(_user, 1 ether);

    // Build metadata to buy specific NFT
    uint16[] memory rawMetadata = new uint16[](1);
    rawMetadata[0] = uint16(tier); // reward tier
    bytes memory metadata = abi.encode(
      bytes32(0),
      bytes32(0),
      type(IJB721Delegate).interfaceId,
      false,
      false,
      false,
      rawMetadata
    );

    // Pay to the project and mint an NFT
    vm.prank(_user);
    _terminals[0].pay{value: 1 ether}(
      _projectId,
      1 ether,
      address(0),
      _user,
      0,
      true,
      '',
      metadata
    );

    JBTiered721SetTierDelegatesData[] memory tiered721SetDelegatesData = new JBTiered721SetTierDelegatesData[](1);
    tiered721SetDelegatesData[0] = JBTiered721SetTierDelegatesData({
        delegatee: _user,
        tierId: uint256(tier)
    });

    // Set the delegate as the user themselves
    vm.prank(_user);
    _nft.setTierDelegates(tiered721SetDelegatesData);

    // The user should now have a balance
    assertEq(
      _nft.balanceOf(_user),
      1
    );

    // Forward 1 block, user should receive all the voting power of the tier, as its the only NFT
    vm.roll(block.number + 1);
    assertEq(
      _nft.store().tier(address(_nft), tier).votingUnits,
      100
    );
    assertEq(_governor.MAX_VOTING_POWER_TIER(), _governor.getVotes(_user, block.number - 1));
  }

  function testSetRedemptionRates(bool _useHelper) public {
    uint8 nTiers = 10;
    address[] memory _users = new address[](nTiers);

    (
      uint256 _projectId,
      DefifaDelegate _nft,
      DefifaGovernor _governor
    ) = createDefifaProject(uint256(nTiers));

    for (uint256 i = 0; i < nTiers; i++) {
      // Generate a new address for each tier
      _users[i] = address(bytes20(keccak256(abi.encode('user', Strings.toString(i)))));

      // fund user
      vm.deal(_users[i], 1 ether);

      // Build metadata to buy specific NFT
      uint16[] memory rawMetadata = new uint16[](1);
      rawMetadata[0] = uint16(i + 1); // reward tier, 1 indexed
      bytes memory metadata = abi.encode(
        bytes32(0),
        bytes32(0),
        type(IJB721Delegate).interfaceId,
        false,
        false,
        false,
        rawMetadata
      );

      // Pay to the project and mint an NFT
      vm.prank(_users[i]);
      _terminals[0].pay{value: 1 ether}(
        _projectId,
        1 ether,
        address(0),
        _users[i],
        0,
        true,
        '',
        metadata
      );

      // Set the delegate as the user themselves
      JBTiered721SetTierDelegatesData[] memory tiered721SetDelegatesData = new JBTiered721SetTierDelegatesData[](1);
      tiered721SetDelegatesData[0] = JBTiered721SetTierDelegatesData({
        delegatee: _users[i],
        tierId: uint256(i + 1)
      });
      vm.prank(_users[i]);
      _nft.setTierDelegates(tiered721SetDelegatesData);

      // Forward 1 block, user should receive all the voting power of the tier, as its the only NFT
      vm.roll(block.number + 1);
      assertEq(_governor.MAX_VOTING_POWER_TIER(), _governor.getVotes(_users[i], block.number - 1));
    }

    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    bytes[] memory calldatas = new bytes[](1);

    // Generate the scorecards
    DefifaTierRedemptionWeight[] memory scorecards = new DefifaTierRedemptionWeight[](nTiers);

    for (uint256 i = 0; i < scorecards.length; i++) {
      scorecards[i].id = i + 1;
      scorecards[i].redemptionWeight = 1_000_000_000 / scorecards.length;
    }

    // Forward time so proposals can be created
    uint256 _proposalId;
    if(_useHelper){
      _proposalId = _governor.submitScorecards(
        scorecards
      );

    }else{
      targets[0] = address(_nft);
      calldatas[0] = abi.encodeCall(_nft.setTierRedemptionWeights, scorecards);

      // Create the proposal
      _proposalId = _governor.propose(targets, values, calldatas, 'Governance!');
    }

    // Forward time so voting becomes active
    vm.roll(block.number + _governor.votingDelay() + 1);
    // '_governor.votingDelay()' internally uses the timestamp and not the block number, so we have to modify it for the next assert
    // block time is 12 secs
    vm.warp(block.timestamp + (_governor.votingDelay() * 12));

    // No voting delay after the initial voting delay has passed in
    assertEq(_governor.votingDelay(), 0);

    // All the users vote
    // 0 = Against
    // 1 = For
    // 2 = Abstain
    for (uint256 i = 0; i < _users.length; i++) {
      vm.prank(_users[i]);
      _governor.castVote(_proposalId, 1);
    }

    // Forward time to the block after voting closes
    vm.roll(_governor.proposalDeadline(_proposalId) + 1);
    // going to the end of the game
    vm.warp(block.timestamp + 3 weeks);

    // Execute the proposal
    if(_useHelper){
      _governor.ratifyScorecard(
        scorecards
      );
    }else{
      _governor.execute(targets, values, calldatas, keccak256('Governance!'));
    }

    uint256[100] memory redemptionWeights = _nft.tierRedemptionWeights();

    // Verify that the redemptionWeights actually changed
    for (uint256 i = 0; i < scorecards.length - 1; i++) {
      assertEq(redemptionWeights[scorecards[i].id], scorecards[i].redemptionWeight);
      scorecards[i].id = i + 1;
      scorecards[i].redemptionWeight = 1_000_000_000 / scorecards.length;
    }
  }

  // ----- internal helpers ------
  function createDefifaProject(uint256 nTiers)
    internal
    returns (
      uint256 projectId,
      DefifaDelegate nft,
      DefifaGovernor governor
    )
  {
    (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData(nTiers);
    
    // launching a default project so we can set splits
    _jbController.launchProjectFor(
      projectOwner, // owner
      launchProjectData.projectMetadata,
      launchProjectData.data,
       JBFundingCycleMetadata({
        global: launchProjectData.metadata.global,
        reservedRate: launchProjectData.metadata.reservedRate,
        redemptionRate: launchProjectData.metadata.redemptionRate,
        ballotRedemptionRate: launchProjectData.metadata.ballotRedemptionRate,
        pausePay: launchProjectData.metadata.pausePay,
        pauseDistributions: launchProjectData.metadata.pauseDistributions,
        pauseRedeem: launchProjectData.metadata.pauseRedeem,
        pauseBurn: launchProjectData.metadata.pauseBurn,
        allowMinting: launchProjectData.metadata.allowMinting,
        allowTerminalMigration: launchProjectData.metadata.allowTerminalMigration,
        allowControllerMigration: launchProjectData.metadata.allowControllerMigration,
        holdFees: launchProjectData.metadata.holdFees,
        preferClaimedTokenOverride: launchProjectData.metadata.preferClaimedTokenOverride,
        useTotalOverflowForRedemptions: launchProjectData.metadata.useTotalOverflowForRedemptions,
        // Set the project to use the data source for its pay function.
        useDataSourceForPay: true,
        useDataSourceForRedeem: true,
        // Set the delegate address as the data source of the provided metadata.
        dataSource: address(0),
        metadata: launchProjectData.metadata.metadata
      }),
      launchProjectData.mustStartAtOrAfter,
      launchProjectData.groupedSplits,
      launchProjectData.fundAccessConstraints,
      launchProjectData.terminals,
      launchProjectData.memo
    );

    DefifaDelegateData memory _delegateData =
      DefifaDelegateData({
        name: NFTRewardDeployerData.name,
        symbol: NFTRewardDeployerData.symbol,
        baseUri: NFTRewardDeployerData.baseUri,
        // TODO: Need a contract URI.
        contractUri: NFTRewardDeployerData.contractUri,
        tiers: NFTRewardDeployerData.pricing.tiers,
        store: NFTRewardDeployerData.store,
        // TODO: set owner as the Governor that is being deployed.
        owner: address(0)
    });

    DefifaLaunchProjectData memory _launchProjectData =
      DefifaLaunchProjectData({
        projectMetadata: launchProjectData.projectMetadata,
        mustStartAtOrAfter: 0,
        mintDuration: 1 weeks,
        start: uint48(block.timestamp + 1 weeks),
        tradeDeadline: uint48(block.timestamp + 2 weeks),
        end: uint48(block.timestamp + 3 weeks),
        holdFees: false,
        splits: new JBSplit[](0),
        distributionLimit: 0,
        terminal: _terminals[0]
      });

    // Deploy the deployer.
    DefifaDeployer defifaDeployer = new DefifaDeployer(_jbController, JBTokens.ETH);

    uint256[] memory _permissionIndexes = new uint256[](1);
    _permissionIndexes[0] = JBOperations.SET_SPLITS;

    vm.startPrank(projectOwner);
    IJBOperatable(address( _terminals[0])).operatorStore().setOperator(JBOperatorData({operator: address(defifaDeployer), domain: 1, permissionIndexes: _permissionIndexes}));
    vm.stopPrank();

    // Set the owner as the governor (done here to easily count future nonces)
    _delegateData.owner = computeCreateAddress(address(this), vm.getNonce(address(this)));

    // Launch the game - initialNonce
    projectId = defifaDeployer.launchGameWith(_delegateData, _launchProjectData);

    // Get a reference to the latest configured funding cycle's data source, which should be the delegate that was deployed and attached to the project.
    (, JBFundingCycleMetadata memory _metadata,) = _jbController.latestConfiguredFundingCycleOf(projectId);

    // Deploy the governor
    governor = new DefifaGovernor(DefifaDelegate(_metadata.dataSource), block.timestamp + 3 weeks);
    
    // making sure the addresses match
    assertEq(address(governor),  _delegateData.owner);

    nft = DefifaDelegate(_metadata.dataSource);
  }

  // Create launchProjectFor(..) payload
  string name = 'NAME';
  string symbol = 'SYM';
  string baseUri = 'http://www.null.com/';
  string contractUri = 'ipfs://null';
  address reserveBeneficiary = address(bytes20(keccak256('reserveBeneficiary')));
  //QmWmyoMoctfbAaiEs2G46gpeUmhqFRDW6KWo64y5r581Vz
  bytes32[] tokenUris = [
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
    bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89)
  ];

  function createData(uint256 n_tiers)
    internal
    returns (
      JBDeployTiered721DelegateData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    )
  {
    JB721TierParams[] memory tierParams = new JB721TierParams[](n_tiers);

    for (uint256 i; i < n_tiers; i++) {
      tierParams[i] = JB721TierParams({
        contributionFloor: 1 ether,
        lockedUntil: 0,
        initialQuantity: 1000,
        votingUnits: 100,
        reservedRate: 1001,
        reservedTokenBeneficiary: address(0),
        encodedIPFSUri: tokenUris[i % tokenUris.length], // this way we dont need more tokenUris
        shouldUseBeneficiaryAsDefault: false,
        allowManualMint: false,
        transfersPausable: false
      });
    }

    NFTRewardDeployerData = JBDeployTiered721DelegateData({
      directory: _jbDirectory,
      name: name,
      symbol: symbol,
      fundingCycleStore: _jbFundingCycleStore,
      baseUri: baseUri,
      tokenUriResolver: IJBTokenUriResolver(address(0)),
      contractUri: contractUri,
      owner: _projectOwner,
      pricing : JB721PricingParams({tiers: tierParams, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
      reservedTokenBeneficiary: reserveBeneficiary,
      store: new JBTiered721DelegateStore(),
      flags: JBTiered721Flags({lockReservedTokenChanges: false, lockVotingUnitChanges: false, lockManualMintingChanges: false}),
      governanceType: JB721GovernanceType.TIERED
    });

    launchProjectData = JBLaunchProjectData({
      projectMetadata: _projectMetadata,
      data: _data,
      metadata: _metadata,
      mustStartAtOrAfter: 0,
      groupedSplits: _groupedSplits,
      fundAccessConstraints: _fundAccessConstraints,
      terminals: _terminals,
      memo: ''
    });
  }
}
