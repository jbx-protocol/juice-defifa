// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import 'forge-std/Test.sol';
import '../DefifaGovernor.sol';
import '../DefifaDeployer.sol';
import '../DefifaDelegate.sol';
import '../DefifaDeployer.sol';

import '@jbx-protocol/juice-721-delegate/contracts/forge-test/utils/TestBaseWorkflow.sol';
import '@jbx-protocol/juice-721-delegate/contracts/structs/JBDeployTiered721DelegateData.sol';
import '@jbx-protocol/juice-721-delegate/contracts/structs/JBLaunchProjectData.sol';
import '@jbx-protocol/juice-721-delegate/contracts/JBTiered721DelegateStore.sol';

contract DefifaGovernorTest is TestBaseWorkflow {
  using JBFundingCycleMetadataResolver for JBFundingCycle;

  DefifaDeployer deployer;

  address projectOwner = address(bytes20(keccak256('projectOwner')));

  function setUp() public virtual override {
    super.setUp();

    DefifaDelegate _delegate = new DefifaDelegate();
    address _protocolFeeProjectTokenAccount = 0x1000000000000000000000000000000000000000;
    deployer = new DefifaDeployer(
      address(_delegate),
      _jbController,
      JBTokens.ETH,
      _protocolFeeProjectTokenAccount
    );
  }

  function testReceiveVotingPower(uint8 nTiers, uint8 tier) public {
    vm.assume(nTiers < 100);
    vm.assume(nTiers >= tier);
    vm.assume(tier != 0);

    address _user = address(bytes20(keccak256('user')));

    DefifaLaunchProjectData memory defifaData = getBasicDefifaLaunchData();
    (uint256 _projectId, DefifaDelegate _nft, DefifaGovernor _governor) = createDefifaProject(
      uint256(nTiers),
      defifaData
    );
    
    // Phase 1: Mint
    vm.warp(defifaData.start - defifaData.mintDuration - defifaData.refundPeriodDuration);
    deployer.queueNextPhaseOf(_projectId);

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

    JBTiered721SetTierDelegatesData[]
      memory tiered721SetDelegatesData = new JBTiered721SetTierDelegatesData[](1);
    tiered721SetDelegatesData[0] = JBTiered721SetTierDelegatesData({
      delegatee: _user,
      tierId: uint256(tier)
    });

    // Set the delegate as the user themselves
    vm.prank(_user);
    _nft.setTierDelegates(tiered721SetDelegatesData);

    // The user should now have a balance
    assertEq(_nft.balanceOf(_user), 1);

    // Forward 1 block, user should receive all the voting power of the tier, as its the only NFT
    vm.roll(block.number + 1);
    assertEq(_nft.store().tier(address(_nft), tier).votingUnits, 100);
    assertEq(_governor.MAX_VOTING_POWER_TIER(), _governor.getVotes(_user, block.number - 1));
  }

  function testRefund_fails_afterMintPhase() external {
    uint8 nTiers = 10;
    address[] memory _users = new address[](nTiers);

    DefifaLaunchProjectData memory defifaData = getBasicDefifaLaunchData();
    (uint256 _projectId, DefifaDelegate _nft, ) = createDefifaProject(
      uint256(nTiers),
      defifaData
    );

      // Phase 1: Mint
    vm.warp(defifaData.start - defifaData.mintDuration - defifaData.refundPeriodDuration);
    deployer.queueNextPhaseOf(_projectId);

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
      JBTiered721SetTierDelegatesData[]
        memory tiered721SetDelegatesData = new JBTiered721SetTierDelegatesData[](1);
      tiered721SetDelegatesData[0] = JBTiered721SetTierDelegatesData({
        delegatee: _users[i],
        tierId: uint256(i + 1)
      });
      vm.prank(_users[i]);
      _nft.setTierDelegates(tiered721SetDelegatesData);
    }

     // Phase 2: Redeem
    vm.warp(block.timestamp + defifaData.mintDuration);
    deployer.queueNextPhaseOf(_projectId);

    // Phase 3: Start
    vm.warp(defifaData.start + 1); 
    deployer.queueNextPhaseOf(_projectId);

    // Make sure this is actually Phase 3
    assertEq(_jbFundingCycleStore.currentOf(_projectId).number, 3);

    for (uint256 i = 0; i < _users.length; i++) {
      address _user = _users[i];

      // Craft the metadata: redeem the tokenId
      bytes memory redemptionMetadata;
      {
        uint256[] memory redemptionId = new uint256[](1);
        redemptionId[0] = _generateTokenId(i + 1, 1);
        redemptionMetadata = abi.encode(bytes32(0), type(IJB721Delegate).interfaceId, redemptionId);
      }

      vm.expectRevert(abi.encodeWithSignature('FUNDING_CYCLE_REDEEM_PAUSED()'));
      vm.prank(_user);
      JBETHPaymentTerminal(address(_terminals[0])).redeemTokensOf({
        _holder: _user,
        _projectId: _projectId,
        _tokenCount: 0,
        _token: address(0),
        _minReturnedTokens: 0,
        _beneficiary: payable(_user),
        _memo: 'Refund plz',
        _metadata: redemptionMetadata
      });
    }

    // Phase 4: End
    vm.warp(deployer.endOf(_projectId));
    // Forward the amount of blocks needed to reach the end (and round up)
    vm.roll(deployer.endOf(_projectId) - block.timestamp / 12 + 1);
    vm.warp(block.timestamp + 1 weeks);
    assertEq(_jbFundingCycleStore.currentOf(_projectId).number, 4);

    for (uint256 i = 0; i < _users.length; i++) {
      address _user = _users[i];

      // Craft the metadata: redeem the tokenId
      bytes memory redemptionMetadata;
      {
        uint256[] memory redemptionId = new uint256[](1);
        redemptionId[0] = _generateTokenId(i + 1, 1);
        redemptionMetadata = abi.encode(bytes32(0), type(IJB721Delegate).interfaceId, redemptionId);
      }

      // Here the refunds are not allowed but redemptions are,
      // so it should instead revert with an error showing that there is no redemption set for our tier
      vm.expectRevert(abi.encodeWithSignature('NOTHING_TO_CLAIM()'));
      vm.prank(_user);
      JBETHPaymentTerminal(address(_terminals[0])).redeemTokensOf({
        _holder: _user,
        _projectId: _projectId,
        _tokenCount: 0,
        _token: address(0),
        _minReturnedTokens: 0,
        _beneficiary: payable(_user),
        _memo: 'Refund plz',
        _metadata: redemptionMetadata
      });
    }
  }

  function testMint_fails_afterMintPhase() external {
    uint8 nTiers = 10;
    address[] memory _users = new address[](nTiers);

    DefifaLaunchProjectData memory defifaData = getBasicDefifaLaunchData();
    (uint256 _projectId,,) = createDefifaProject(
      uint256(nTiers),
      defifaData
    );

    // Phase 1: minting
    vm.warp(defifaData.start - defifaData.mintDuration - defifaData.refundPeriodDuration);
    deployer.queueNextPhaseOf(_projectId);

    // Phase 2: Redeem
    vm.warp(block.timestamp + defifaData.mintDuration);
    deployer.queueNextPhaseOf(_projectId);

    // Make sure this is actually Phase 2
    assertEq(_jbFundingCycleStore.currentOf(_projectId).number, 2);

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
        rawMetadata
      );

      // Pay to the project and mint an NFT
      vm.expectRevert(abi.encodeWithSignature('FUNDING_CYCLE_PAYMENT_PAUSED()'));
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
    }

    // Phase 3: Start
    vm.warp(defifaData.start + 1); 
    deployer.queueNextPhaseOf(_projectId);

    // Make sure this is actually Phase 3
    assertEq(_jbFundingCycleStore.currentOf(_projectId).number, 3);

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
        rawMetadata
      );

      // Pay to the project and mint an NFT
      vm.expectRevert(abi.encodeWithSignature('FUNDING_CYCLE_PAYMENT_PAUSED()'));
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
    }

    // Phase 4: End
    vm.warp(deployer.endOf(_projectId));
    // Forward the amount of blocks needed to reach the end (and round up)
    vm.roll(deployer.endOf(_projectId) - block.timestamp / 12 + 1);
    // Make sure this is actually Phase 4
    assertEq(_jbFundingCycleStore.currentOf(_projectId).number, 4);

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
        rawMetadata
      );

      // Pay to the project and mint an NFT
      vm.expectRevert(abi.encodeWithSignature('FUNDING_CYCLE_PAYMENT_PAUSED()'));
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
    }
  }

  // Transfers are no longer disabled
  // function testTransfer_fails_afterTradeDeadline() external {
  //   uint8 nTiers = 10;
  //   address[] memory _users = new address[](nTiers);

  //   DefifaLaunchProjectData memory defifaData = getBasicDefifaLaunchData();
  //   (uint256 _projectId, DefifaDelegate _nft, ) = createDefifaProject(
  //     uint256(nTiers),
  //     getBasicDefifaLaunchData()
  //   );

  //   // Phase 1: minting
  //   vm.warp(defifaData.start - defifaData.mintDuration - defifaData.refundPeriodDuration);

  //   for (uint256 i = 0; i < nTiers; i++) {
  //     // Generate a new address for each tier
  //     _users[i] = address(bytes20(keccak256(abi.encode('user', Strings.toString(i)))));

  //     // fund user
  //     vm.deal(_users[i], 1 ether);

  //     // Build metadata to buy specific NFT
  //     uint16[] memory rawMetadata = new uint16[](1);
  //     rawMetadata[0] = uint16(i + 1); // reward tier, 1 indexed
  //     bytes memory metadata = abi.encode(
  //       bytes32(0),
  //       bytes32(0),
  //       type(IJB721Delegate).interfaceId,
  //       false,
  //       false,
  //       false,
  //       rawMetadata
  //     );

  //     // Pay to the project and mint an NFT
  //     vm.prank(_users[i]);
  //     _terminals[0].pay{value: 1 ether}(
  //       _projectId,
  //       1 ether,
  //       address(0),
  //       _users[i],
  //       0,
  //       true,
  //       '',
  //       metadata
  //     );
  //   }

  //   // Phase 2: Redeem
  //   vm.warp(block.timestamp + defifaData.mintDuration);
  //   deployer.queueNextPhaseOf(_projectId);

  //   // Make sure this is actually Phase 2
  //   assertEq(_jbFundingCycleStore.currentOf(_projectId).number, 2);

  //   // Phase 3: Start
  //   vm.warp(defifaData.start + 1); 
  //   deployer.queueNextPhaseOf(_projectId);

  //   // Make sure this is actually Phase 3
  //   assertEq(_jbFundingCycleStore.currentOf(_projectId).number, 3);

  //   uint256 _tokenIdToTransfer = _generateTokenId(1, 1);
  //   vm.prank(_users[0]);
  //   // trasnfers not possible in phase 3
  //   vm.expectRevert(abi.encodeWithSignature('TRANSFERS_PAUSED()'));
  //   _nft.transferFrom(_users[0], _users[1], _tokenIdToTransfer);
  // }

  function testSetRedemptionRates_fails_unmetQuorum() external {
    uint8 nTiers = 10;
    address[] memory _users = new address[](nTiers);

    DefifaLaunchProjectData memory defifaData = getBasicDefifaLaunchData();
    (uint256 _projectId, DefifaDelegate _nft, DefifaGovernor _governor) = createDefifaProject(
      uint256(nTiers),
      defifaData
    );

    // Phase 1: minting
    vm.warp(defifaData.start - defifaData.mintDuration - defifaData.refundPeriodDuration);
    deployer.queueNextPhaseOf(_projectId);

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
      JBTiered721SetTierDelegatesData[]
        memory tiered721SetDelegatesData = new JBTiered721SetTierDelegatesData[](1);
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

    // Phase 2: Redeem
    vm.warp(block.timestamp + defifaData.mintDuration);
    deployer.queueNextPhaseOf(_projectId);

    // Phase 3: Start
    vm.warp(defifaData.start + 1); 
    deployer.queueNextPhaseOf(_projectId);

    // Generate the scorecards
    DefifaTierRedemptionWeight[] memory scorecards = new DefifaTierRedemptionWeight[](nTiers);

    // We can't have a neutral outcome, so we only give shares to tiers that are an even number (in our array)
    for (uint256 i = 0; i < scorecards.length; i++) {
      scorecards[i].id = i + 1;
      scorecards[i].redemptionWeight = i % 2 == 0 ? 1_000_000_000 / (scorecards.length / 2) : 0;
    }

    // Forward time so proposals can be created
    uint256 _proposalId = _governor.submitScorecards(scorecards);
    // Forward time so voting becomes active
    vm.roll(block.number + _governor.votingDelay() + 1);
    // '_governor.votingDelay()' internally uses the timestamp and not the block number, so we have to modify it for the next assert
    // block time is 12 secs
    vm.warp(block.timestamp + (_governor.votingDelay() * 12));

    // No voting delay after the initial voting delay has passed in
    assertEq(_governor.votingDelay(), 0);

    // We have 60% vote against and 40% vote in favor
    for (uint256 i = 0; i < _users.length; i++) {
      vm.prank(_users[i]);
      _governor.castVote(_proposalId, 0);
    }

    // Phase 4: End
    vm.warp(deployer.endOf(_projectId));
    // Forward the amount of blocks needed to reach the end (and round up)
    vm.roll(deployer.endOf(_projectId) - block.timestamp / 12 + 1);
    vm.warp(block.timestamp + 1 weeks);

    // Execute the proposal
    vm.expectRevert('Governor: proposal not successful');
    _governor.ratifyScorecard(scorecards);
  }

  function testSetRedemptionRates_fails_declined() external {
    uint8 nTiers = 10;
    address[] memory _users = new address[](nTiers);

    DefifaLaunchProjectData memory defifaData = getBasicDefifaLaunchData();
    (uint256 _projectId, DefifaDelegate _nft, DefifaGovernor _governor) = createDefifaProject(
      uint256(nTiers),
      defifaData
    );

    // Phase 1: minting
    vm.warp(defifaData.start - defifaData.mintDuration - defifaData.refundPeriodDuration);
    deployer.queueNextPhaseOf(_projectId);

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
      JBTiered721SetTierDelegatesData[]
        memory tiered721SetDelegatesData = new JBTiered721SetTierDelegatesData[](1);
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

    // Phase 2: Redeem
    vm.warp(block.timestamp + defifaData.mintDuration);
    deployer.queueNextPhaseOf(_projectId);

    // Phase 3: Start
    vm.warp(defifaData.start + 1); 
    deployer.queueNextPhaseOf(_projectId);

    // Generate the scorecards
    DefifaTierRedemptionWeight[] memory scorecards = new DefifaTierRedemptionWeight[](nTiers);

    // We can't have a neutral outcome, so we only give shares to tiers that are an even number (in our array)
    for (uint256 i = 0; i < scorecards.length; i++) {
      scorecards[i].id = i + 1;
      scorecards[i].redemptionWeight = i % 2 == 0 ? 1_000_000_000 / (scorecards.length / 2) : 0;
    }

    // Forward time so proposals can be created
    uint256 _proposalId = _governor.submitScorecards(scorecards);
    // Forward time so voting becomes active
    vm.roll(block.number + _governor.votingDelay() + 1);
    // '_governor.votingDelay()' internally uses the timestamp and not the block number, so we have to modify it for the next assert
    // block time is 12 secs
    vm.warp(block.timestamp + (_governor.votingDelay() * 12));

    // No voting delay after the initial voting delay has passed in
    assertEq(_governor.votingDelay(), 0);

    // We have 60% vote against and 40% vote in favor
    for (uint256 i = 0; i < _users.length; i++) {
      vm.prank(_users[i]);
      _governor.castVote(_proposalId, 0);
    }

   // Phase 4: End
    vm.warp(deployer.endOf(_projectId));
    vm.roll(deployer.endOf(_projectId));
    vm.warp(block.timestamp + 1 weeks);

    // Execute the proposal
    vm.expectRevert('Governor: proposal not successful');
    _governor.ratifyScorecard(scorecards);
  }

  function testSetRedemptionRatesAndRedeem_multipleTiers(
    uint8 nTiers,
    uint8[] calldata distribution
  ) public {
    vm.assume(nTiers > 10 && nTiers < 100);
    vm.assume(distribution.length < nTiers);

    uint256 _sumDistribution;
    for (uint256 i = 0; i < distribution.length; i++) {
      _sumDistribution += distribution[i];
    }

    vm.assume(_sumDistribution > 0);

    address[] memory _users = new address[](nTiers);

    DefifaLaunchProjectData memory defifaData = getBasicDefifaLaunchData();
    (uint256 _projectId, DefifaDelegate _nft, DefifaGovernor _governor) = createDefifaProject(
      uint256(nTiers),
      defifaData
    );

    // Phase 1: minting
    vm.warp(defifaData.start - defifaData.mintDuration - defifaData.refundPeriodDuration);
    deployer.queueNextPhaseOf(_projectId);

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

      // Forward 1 block, user should receive all the voting power of the tier, as its the only NFT
      vm.roll(block.number + 1);
      assertEq(_governor.MAX_VOTING_POWER_TIER(), _governor.getVotes(_users[i], block.number - 1));

      // Have a user mint and refund the tier
      mintAndRefund(_nft, _projectId, i + 1);
    }

    // Have a user mint and refund the tier
    mintAndRefund(_nft, _projectId, 1);

     // Phase 2: Redeem
    vm.warp(block.timestamp + defifaData.mintDuration);
    deployer.queueNextPhaseOf(_projectId);

    // Phase 3: Start
    vm.warp(defifaData.start + 1); 
    deployer.queueNextPhaseOf(_projectId);

    // Generate the scorecards
    DefifaTierRedemptionWeight[] memory scorecards = new DefifaTierRedemptionWeight[](nTiers);

    // We can't have a neutral outcome, so we only give shares to tiers that are an even number (in our array)
    for (uint256 i = 0; i < scorecards.length; i++) {
      scorecards[i].id = i + 1;

      if (distribution.length <= i) continue;
      scorecards[i].redemptionWeight =
        (uint256(distribution[i]) * 1_000_000_000) /
        _sumDistribution;
    }

    // Forward time so proposals can be created
    uint256 _proposalId = _governor.submitScorecards(scorecards);

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

    // Phase 4: End
    vm.warp(deployer.endOf(_projectId));
    // Forward the amount of blocks needed to reach the end (and round up)
    vm.roll(deployer.endOf(_projectId) - block.timestamp / 12 + 1);
    vm.warp(block.timestamp + 1 weeks);

    _governor.ratifyScorecard(scorecards);
    vm.roll(block.number + 1);

    // Verify that the redemptionWeights actually changed
    for (uint256 i = 0; i < scorecards.length; i++) {
      address _user = _users[i];

      // Tier's are 1 indexed and should be stored 0 indexed.
      assertEq(_nft.tierRedemptionWeights()[i], scorecards[i].redemptionWeight);

      // Craft the metadata: redeem the tokenId
      bytes memory redemptionMetadata;
      {
        uint256[] memory redemptionId = new uint256[](1);
        redemptionId[0] = _generateTokenId(i + 1, 1);
        redemptionMetadata = abi.encode(bytes32(0), type(IJB721Delegate).interfaceId, redemptionId);
      }

      // If the redemption is 0 this will revert
      if (scorecards[i].redemptionWeight == 0)
        vm.expectRevert(abi.encodeWithSignature('NOTHING_TO_CLAIM()'));

      vm.prank(_user);
      JBETHPaymentTerminal(address(_terminals[0])).redeemTokensOf({
        _holder: _user,
        _projectId: _projectId,
        _tokenCount: 0,
        _token: address(0),
        _minReturnedTokens: 0,
        _beneficiary: payable(_user),
        _memo: 'imma out of here',
        _metadata: redemptionMetadata
      });

      if (scorecards[i].redemptionWeight == 0) continue;

      // We calculate the expected output based on the given distribution and how much is in the pot
      uint256 _expectedTierRedemption = uint256(nTiers) * 1 ether;
      _expectedTierRedemption = (_expectedTierRedemption * distribution[i]) / _sumDistribution;

      // Assert that our expected tier redemption is ~equal to the actual amount
      // Allowing for some rounding errors, max allowed error is 0.000001 ether
      assertLt(_expectedTierRedemption - _user.balance, 10**12);
    }

    // All NFTs should have been redeemed, only some dust should be left
    // Max allowed dust is 0.0001
    assertLt(address(_terminals[0]).balance, 10**14);
  }

  function testSetRedemptionRatesAndRedeem_singleTier(
    uint8 nUsersWithWinningTier,
    uint8 winningTierExtraWeight,
    uint8 baseRedemptionWeight
  ) public {
    uint256 nOfOtherTiers = 31;
    vm.assume(nUsersWithWinningTier > 1 && nUsersWithWinningTier < 100);

    uint256 totalWeight = baseRedemptionWeight * (nOfOtherTiers + 1) + winningTierExtraWeight;
    vm.assume(totalWeight > 1);

    address[] memory _users = new address[](nOfOtherTiers + nUsersWithWinningTier);

     DefifaLaunchProjectData memory defifaData = getBasicDefifaLaunchData();
    (uint256 _projectId, DefifaDelegate _nft, DefifaGovernor _governor) = createDefifaProject(
      uint256(nOfOtherTiers + 1), // All users will buying the same tier
      defifaData
    );

    // Phase 1: minting
    vm.warp(defifaData.start - defifaData.mintDuration - defifaData.refundPeriodDuration);

    for (uint256 i = 0; i < nOfOtherTiers + nUsersWithWinningTier; i++) {
      // Generate a new address for each tier
      _users[i] = address(bytes20(keccak256(abi.encode('user', Strings.toString(i)))));

      // We randomly decide if we have a user mint and refund
      //mintAndRefund(_nft, _projectId, i + 1);

      // fund user
      vm.deal(_users[i], 1 ether);

      if (i < nOfOtherTiers) {
        // Build metadata to buy specific NFT
        uint16[] memory rawMetadata = new uint16[](1);
        rawMetadata[0] = uint16(i + 1); // reward tier, 1 indexed
        bytes memory metadata = abi.encode(
          bytes32(0),
          bytes32(0),
          type(IJB721Delegate).interfaceId,
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

        // Forward 1 block, user should receive all the voting power of the tier, as its the only NFT
        vm.roll(block.number + 1);
        assertEq(
          _governor.MAX_VOTING_POWER_TIER(),
          _governor.getVotes(_users[i], block.number - 1)
        );
      } else {
        // Build metadata to buy specific NFT
        uint16[] memory rawMetadata = new uint16[](1);
        rawMetadata[0] = uint16(nOfOtherTiers + 1); // reward tier, 1 indexed
        bytes memory metadata = abi.encode(
          bytes32(0),
          bytes32(0),
          type(IJB721Delegate).interfaceId,
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

        // Forward 1 block, user should have a part of the voting power of their tier
        vm.roll(block.number + 1);
        assertEq(
          _governor.MAX_VOTING_POWER_TIER() / (i - nOfOtherTiers + 1),
          _governor.getVotes(_users[i], block.number - 1)
        );
      }
    }

    // Have a user mint and refund the tier
    mintAndRefund(_nft, _projectId, 1);

    // Phase 2: Redeem
    vm.warp(block.timestamp + defifaData.mintDuration);
    deployer.queueNextPhaseOf(_projectId);

    // Phase 3: Start
    vm.warp(defifaData.start + 1); 
    deployer.queueNextPhaseOf(_projectId);

    // Generate the scorecards
    DefifaTierRedemptionWeight[] memory scorecards = new DefifaTierRedemptionWeight[](
      nOfOtherTiers + 1
    );

    // We can't have a neutral outcome, so we only give shares to tiers that are an even number (in our array)
    for (uint256 i = 0; i < scorecards.length; i++) {
      scorecards[i].id = i + 1;
      if (baseRedemptionWeight != 0)
        scorecards[i].redemptionWeight =
          (1_000_000_000 * uint256(baseRedemptionWeight)) /
          totalWeight;

      if (i == nOfOtherTiers && winningTierExtraWeight != 0)
        scorecards[i].redemptionWeight +=
          (1_000_000_000 * uint256(winningTierExtraWeight)) /
          totalWeight;
    }

    {
      // Forward time so proposals can be created
      uint256 _proposalId = _governor.submitScorecards(scorecards);

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
    }

    // Phase 4: End
    // Forward the amount of blocks needed to reach the end (and round up)
    vm.roll(deployer.endOf(_projectId) - block.timestamp / 12 + 1);
    vm.warp(deployer.endOf(_projectId));
    deployer.queueNextPhaseOf(_projectId);
    vm.warp(block.timestamp + 1 weeks);

    _governor.ratifyScorecard(scorecards);
    vm.roll(block.number + 1);

    // Verify that the redemptionWeights actually changed
    for (uint256 i = 0; i < _users.length; i++) {
      address _user = _users[i];
      uint256 _tier = i <= nOfOtherTiers ? i + 1 : nOfOtherTiers + 1;

      // Craft the metadata: redeem the tokenId
      bytes memory redemptionMetadata;
      {
        uint256[] memory redemptionId = new uint256[](1);
        redemptionId[0] = _generateTokenId(
          _tier,
          _tier == nOfOtherTiers + 1 ? i - nOfOtherTiers + 1 : 1
        );
        redemptionMetadata = abi.encode(bytes32(0), type(IJB721Delegate).interfaceId, redemptionId);
      }
      uint256 _expectedTierRedemption;
      {
      // Calculate how much weight his tier has
      uint256 _tierWeight = _tier == nOfOtherTiers + 1
        ? uint256(baseRedemptionWeight) + uint256(winningTierExtraWeight)
        : baseRedemptionWeight;

      // If the redemption is 0 this will revert
      if (_tierWeight == 0) vm.expectRevert(abi.encodeWithSignature('NOTHING_TO_CLAIM()'));

      vm.prank(_user);
      JBETHPaymentTerminal(address(_terminals[0])).redeemTokensOf({
        _holder: _user,
        _projectId: _projectId,
        _tokenCount: 0,
        _token: address(0),
        _minReturnedTokens: 0,
        _beneficiary: payable(_user),
        _memo: 'imma out of here',
        _metadata: redemptionMetadata
      });

      // We calculate the expected output based on the given distribution and how much is in the pot
      _expectedTierRedemption = (uint256(_users.length) * 1 ether * _tierWeight) /
        totalWeight;
      }
      {
        // If this is the winning tier then the amount is divided among the nUsersWithWinningTier
        if (_tier == nOfOtherTiers + 1)
          _expectedTierRedemption = _expectedTierRedemption / nUsersWithWinningTier;
      }

      // Assert that our expected tier redemption is ~equal to the actual amount
      // Allowing for some rounding errors, max allowed error is 0.000001 ether
      assertLt(_expectedTierRedemption - _user.balance, 10**12);
    }

    // All NFTs should have been redeemed, only some dust should be left
    // Max allowed dust is 0.0001
    assertLt(address(_terminals[0]).balance, 10**14);
  }

  function testPhaseTimes(
    uint16 _durationUntilProjectLaunch,
    uint16 _mintDuration,
    uint16 _inBetweenMintAndFifa,
    uint16 _fifaDuration
  ) public {
    vm.warp(1667953355);

    vm.assume(
      _durationUntilProjectLaunch > 2 &&
        _mintDuration > 1 &&
        _inBetweenMintAndFifa > 1 &&
        _fifaDuration > 1
    );

    uint48 _launchProjectAt = uint48(block.timestamp) + _durationUntilProjectLaunch;
    uint48 _end = _launchProjectAt +
      uint48(_mintDuration) +
      uint48(_inBetweenMintAndFifa) +
      uint48(_fifaDuration);

    DefifaLaunchProjectData memory _launchData = DefifaLaunchProjectData({
      projectMetadata: JBProjectMetadata({content: '', domain: 0}),
      mintDuration: _mintDuration,
      start: _launchProjectAt + uint48(_mintDuration) + _inBetweenMintAndFifa,
      refundPeriodDuration: _inBetweenMintAndFifa,
      end: _end,
      holdFees: false,
      splits: new JBSplit[](0),
      distributionLimit: 0,
      terminal: _jbETHPaymentTerminal
    });

    (uint256 _projectId, DefifaDelegate _nft, ) = createDefifaProject(uint256(10), _launchData);

    // Wait until the phase 1 start
    vm.warp(_launchProjectAt);
    // Get the delegate
    _nft = DefifaDelegate(_jbFundingCycleStore.currentOf(_projectId).dataSource());

    // We should be in the minting phase now
    assertEq(_jbFundingCycleStore.currentOf(_projectId).number, 1);
    // Queue Phase 2
    deployer.queueNextPhaseOf(_projectId);

    // Go to the end of the minting phase and check if we are still in the minting phase
    vm.warp(_launchProjectAt + _mintDuration - 1);
    assertEq(_jbFundingCycleStore.currentOf(_projectId).number, 1);

    // We should now be in phase 2, minting is paused and the treasury is frozen
    vm.warp(_launchProjectAt + _mintDuration);
    assertEq(_jbFundingCycleStore.currentOf(_projectId).number, 2);

    // Queue Phase 3
    deployer.queueNextPhaseOf(_projectId);

    // Go to the end of phase 2
    vm.warp(_launchProjectAt + _mintDuration + _inBetweenMintAndFifa - 1);
    assertEq(_jbFundingCycleStore.currentOf(_projectId).number, 2);

    // We should now be in phase 3, trading deadline (start of fifa)
    vm.warp(_launchProjectAt + _mintDuration + _inBetweenMintAndFifa);
    assertEq(_jbFundingCycleStore.currentOf(_projectId).number, 3);

    // Go to the end of phase 3
    vm.warp(_launchProjectAt + _mintDuration + _inBetweenMintAndFifa + _fifaDuration - 1);
    assertEq(_jbFundingCycleStore.currentOf(_projectId).number, 3);

    // Queue Phase 4
    deployer.queueNextPhaseOf(_projectId);

    // We should now be in phase 4, game has ended
    vm.warp(_launchProjectAt + _mintDuration + _inBetweenMintAndFifa + _fifaDuration);
    assertEq(_jbFundingCycleStore.currentOf(_projectId).number, 4);
  }

  function testWhenPhaseIsAlreadyQueued() public {
    uint8 nTiers = 10;
    address[] memory _users = new address[](nTiers);

    DefifaLaunchProjectData memory defifaData = getBasicDefifaLaunchData();
    (uint256 _projectId, DefifaDelegate _nft, DefifaGovernor _governor) = createDefifaProject(
      uint256(nTiers),
      defifaData
    );
    
    // Phase 1: Mint
    vm.warp(defifaData.start - defifaData.mintDuration - defifaData.refundPeriodDuration);
    deployer.queueNextPhaseOf(_projectId);

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
      JBTiered721SetTierDelegatesData[]
        memory tiered721SetDelegatesData = new JBTiered721SetTierDelegatesData[](1);
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

    // Phase 2: Redeem
    vm.warp(block.timestamp + defifaData.mintDuration);
    deployer.queueNextPhaseOf(_projectId);

     // Right at the end of Phase 2
    vm.warp(defifaData.start - 1); 
    vm.expectRevert(abi.encodeWithSignature('PHASE_ALREADY_QUEUED()'));
    deployer.queueNextPhaseOf(_projectId);
  }

  function testSettingTierRedemptionWeightBeforeEndPhase() public {
    uint8 nTiers = 10;
    address[] memory _users = new address[](nTiers);

    DefifaLaunchProjectData memory defifaData = getBasicDefifaLaunchData();
    (uint256 _projectId, DefifaDelegate _nft, DefifaGovernor _governor) = createDefifaProject(
      uint256(nTiers),
      defifaData
    );
    
    // Phase 1: Mint
    vm.warp(defifaData.start - defifaData.mintDuration - defifaData.refundPeriodDuration);
    deployer.queueNextPhaseOf(_projectId);

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
      JBTiered721SetTierDelegatesData[]
        memory tiered721SetDelegatesData = new JBTiered721SetTierDelegatesData[](1);
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

    // Phase 2: Redeem
    vm.warp(block.timestamp + defifaData.mintDuration);
    deployer.queueNextPhaseOf(_projectId);

    // Phase 3: Start
    vm.warp(defifaData.start + 1); 
    deployer.queueNextPhaseOf(_projectId);

    // Generate the scorecards
    DefifaTierRedemptionWeight[] memory scorecards = new DefifaTierRedemptionWeight[](nTiers);

    // We can't have a neutral outcome, so we only give shares to tiers that are an even number (in our array)
    for (uint256 i = 0; i < scorecards.length; i++) {
      scorecards[i].id = i + 1;
      scorecards[i].redemptionWeight = i % 2 == 0 ? 1_000_000_000 / (scorecards.length / 2) : 0;
    }

    // Forward time so proposals can be created
    uint256 _proposalId = _governor.submitScorecards(scorecards);

    // Forward time so voting becomes active
    vm.roll(block.number + _governor.votingDelay() + 1);
    // '_governor.votingDelay()' internally uses the timestamp and not the block number, so we have to modify it for the next assert
    // block time is 12 secs
    vm.warp(block.timestamp + (_governor.votingDelay() * 12));

    // All the users vote
    // 0 = Against
    // 1 = For
    // 2 = Abstain
    for (uint256 i = 0; i < _users.length; i++) {
      vm.prank(_users[i]);
      _governor.castVote(_proposalId, 1);
    }

    // Execute the proposal
    vm.expectRevert('Governor: proposal not successful'); // phhase 4 not reached yet
    _governor.ratifyScorecard(scorecards);
  }

  function testWhenRedemptionWeightisMoreThanMaxRedemptionWeight() public {
    uint8 nTiers = 10;
    address[] memory _users = new address[](nTiers);

    DefifaLaunchProjectData memory defifaData = getBasicDefifaLaunchData();
    (uint256 _projectId, DefifaDelegate _nft, DefifaGovernor _governor) = createDefifaProject(
      uint256(nTiers),
      defifaData
    );
    
    // Phase 1: Mint
    vm.warp(defifaData.start - defifaData.mintDuration - defifaData.refundPeriodDuration);
    deployer.queueNextPhaseOf(_projectId);

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
      JBTiered721SetTierDelegatesData[]
        memory tiered721SetDelegatesData = new JBTiered721SetTierDelegatesData[](1);
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

    // Phase 2: Redeem
    vm.warp(block.timestamp + defifaData.mintDuration);
    deployer.queueNextPhaseOf(_projectId);

    // Phase 3: Start
    vm.warp(defifaData.start + 1); 
    deployer.queueNextPhaseOf(_projectId);

    // Generate the scorecards
    DefifaTierRedemptionWeight[] memory scorecards = new DefifaTierRedemptionWeight[](nTiers);

    // We can't have a neutral outcome, so we only give shares to tiers that are an even number (in our array)
    for (uint256 i = 0; i < scorecards.length; i++) {
      scorecards[i].id = i + 1;
      scorecards[i].redemptionWeight = 1_000_000_000;
    }

    // Forward time so proposals can be created
    uint256 _proposalId = _governor.submitScorecards(scorecards);

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

    // Phase 4: End
    vm.warp(deployer.endOf(_projectId));
    vm.roll(deployer.endOf(_projectId));
    vm.warp(block.timestamp + 1 weeks);

    // Execute the proposal
    vm.expectRevert(abi.encodeWithSignature('INVALID_REDEMPTION_WEIGHTS()'));
    _governor.ratifyScorecard(scorecards);
  }

  function getBasicDefifaLaunchData() internal view returns (DefifaLaunchProjectData memory) {
    return
      DefifaLaunchProjectData({
        projectMetadata: JBProjectMetadata({content: '', domain: 0}),
        mintDuration: 1 days,
        start: uint48(block.timestamp + 3 days),
        refundPeriodDuration: 1 days,
        //tradeDeadline: uint48(block.timestamp + 1 days),
        end: uint48(block.timestamp + 3 days + 1 weeks),
        holdFees: false,
        splits: new JBSplit[](0),
        distributionLimit: 0,
        terminal: _jbETHPaymentTerminal
      });
  }

  // ----- internal helpers ------
  function createDefifaProject(uint256 nTiers, DefifaLaunchProjectData memory defifaLaunchData)
    internal
    returns (
      uint256 projectId,
      DefifaDelegate nft,
      DefifaGovernor governor
    )
  {
    (JBDeployTiered721DelegateData memory NFTRewardDeployerData, ) = createData(nTiers);

    // Set the owner as the governor (done here to easily count future nonces)
    // in the tests the nonce of address(this) is updated when doing deployments so hence
    address _owner = computeCreateAddress(address(this), vm.getNonce(address(this)));

    projectId = deployer.launchGameWith(
      DefifaDelegateData({
        name: NFTRewardDeployerData.name,
        symbol: NFTRewardDeployerData.symbol,
        baseUri: NFTRewardDeployerData.baseUri,
        contractUri: NFTRewardDeployerData.contractUri,
        tiers: NFTRewardDeployerData.pricing.tiers,
        store: NFTRewardDeployerData.store,
        owner: _owner
      }),
      defifaLaunchData
    );

    // Get a reference to the latest configured funding cycle's data source, which should be the delegate that was deployed and attached to the project.
    JBFundingCycle memory _fc = _jbFundingCycleStore.currentOf(projectId);

    if (_fc.dataSource() == address(0)) {
      _fc = _jbFundingCycleStore.queuedOf(projectId);
    }

    // Deploy the governor
    governor = new DefifaGovernor(DefifaDelegate(_fc.dataSource()), uint48(block.timestamp + 10 days + 1 weeks));

    // making sure the addresses match
    assertEq(address(governor), _owner);

    nft = DefifaDelegate(_fc.dataSource());
  }

  function mintAndRefund(
    DefifaDelegate _delegate,
    uint256 _projectId,
    uint256 _tierId
  ) internal {
    JB721Tier memory _tier = _delegate.store().tier(address(_delegate), _tierId);
    uint256 _cost = _tier.contributionFloor;
    address _refundUser = address(bytes20(keccak256('refund_user')));

    // The user should have no balance
    assertEq(_delegate.balanceOf(_refundUser), 0);

    // Build metadata to buy specific NFT
    uint16[] memory rawMetadata = new uint16[](1);
    rawMetadata[0] = uint16(_tierId); // reward tier, 1 indexed
    bytes memory metadata = abi.encode(
      bytes32(0),
      bytes32(0),
      type(IJB721Delegate).interfaceId,
      false,
      rawMetadata
    );

    // Pay to the project and mint an NFT
    vm.deal(_refundUser, _cost);
    vm.prank(_refundUser);
    _terminals[0].pay{value: _cost}(
      _projectId,
      _cost,
      address(0),
      _refundUser,
      0,
      true,
      '',
      metadata
    );

    // User should no longer have any funds
    assertEq(_refundUser.balance, 0);

    // The user should have have a token
    assertEq(_delegate.balanceOf(_refundUser), 1);

    uint256 _numberBurned = _delegate.store().numberOfBurnedFor(address(_delegate), _tierId);

    // Craft the metadata: redeem the tokenId
    bytes memory redemptionMetadata;
    {
      uint256[] memory redemptionId = new uint256[](1);
      redemptionId[0] = _generateTokenId(
        _tierId,
        _tier.initialQuantity - _tier.remainingQuantity + 1 + _numberBurned
      );
      redemptionMetadata = abi.encode(bytes32(0), type(IJB721Delegate).interfaceId, redemptionId);
    }

    vm.prank(_refundUser);
    JBETHPaymentTerminal(address(_terminals[0])).redeemTokensOf({
      _holder: _refundUser,
      _projectId: _projectId,
      _tokenCount: 0,
      _token: address(0),
      _minReturnedTokens: 0,
      _beneficiary: payable(_refundUser),
      _memo: 'imma out of here',
      _metadata: redemptionMetadata
    });

    // User should have their original funds again
    assertEq(_refundUser.balance, _cost);
    // User should no longer have the NFT
    assertEq(_delegate.balanceOf(_refundUser), 0);
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
        transfersPausable: true
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
      pricing: JB721PricingParams({
        tiers: tierParams,
        currency: 1,
        decimals: 18,
        prices: IJBPrices(address(0))
      }),
      reservedTokenBeneficiary: reserveBeneficiary,
      store: new JBTiered721DelegateStore(),
      flags: JBTiered721Flags({
        preventOverspending: true,
        lockReservedTokenChanges: false,
        lockVotingUnitChanges: false,
        lockManualMintingChanges: false
      }),
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

  function _generateTokenId(uint256 _tierId, uint256 _tokenNumber) internal pure returns (uint256) {
    return (_tierId * 1_000_000_000) + _tokenNumber;
  }
}
