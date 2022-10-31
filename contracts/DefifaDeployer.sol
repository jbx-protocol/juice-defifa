// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBConstants.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/libraries/JBSplitsGroups.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundAccessConstraints.sol';
import './interfaces/IDefifaDeployer.sol';
import './structs/DefifaStoredOpsData.sol';
import './DefifaDelegate.sol';

/**
  @title
  DefifaDeployer

  @notice
  Deploys a Defifa game.

  @dev
  Adheres to -
  IDefifaDeployer: General interface for the generic controller methods in this contract that interacts with funding cycles and tokens according to the protocol's rules.
*/
contract DefifaDeployer is IDefifaDeployer {
  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//
  error INVALID_GAME_CONFIGURATION();
  error PHASE_ALREADY_QUEUED();
  error GAME_OVER();
  error UNEXPECTED_TERMINAL_CURRENCY();

  //*********************************************************************//
  // ----------------------- internal proprties ------------------------ //
  //*********************************************************************//

  /** 
    @notice
    Start time of the 2nd fc when re-configuring the fc. 
  */
  mapping(uint256 => DefifaTimeData) internal _timesFor;

  /** 
    @notice
    Operations variables for a game.

    @dev
    Includes the payment terminal being used, the distribution limit, and wether or not fees should be held.
  */
  mapping(uint256 => DefifaStoredOpsData) internal _opsFor;

  //*********************************************************************//
  // ------------------------ public constants ------------------------- //
  //*********************************************************************//

  /**
    @notice
    The project ID relative to which splits are stored.

    @dev
    The owner of this project ID must give this contract operator permissions over the SET_SPLITS operation.
  */
  uint256 public constant override SPLIT_PROJECT_ID = 1;

  /** 
    @notice
    The domain relative to which splits are stored.

    @dev
    This could be any fixed number.
  */
  uint256 public constant override SPLIT_DOMAIN = 0;

  //*********************************************************************//
  // --------------- public immutable stored properties ---------------- //
  //*********************************************************************//

  /** 
    @notice
    The token this game is played with.
  */
  address public override immutable token;

  /**
    @notice
    The controller with which new projects should be deployed. 
  */
  IJBController public override immutable controller;

  /** 
    @notice
    The contract responsibile for deploying the delegate. 
  */
  IJBTiered721DelegateDeployer public immutable delegateDeployer;

  //*********************************************************************//
  // ------------------------- external views -------------------------- //
  //*********************************************************************//

  function timesFor(uint256 _gameId) external view override returns (DefifaTimeData memory) {
    return _timesFor[_gameId];
  }

  function startOf(uint256 _gameId) external view override returns (uint256) {
    return _timesFor[_gameId].start;
  }

  function tradeDeadlineOf(uint256 _gameId) external view override returns (uint256) {
    return _timesFor[_gameId].tradeDeadline;
  }

  function endOf(uint256 _gameId) external view override returns (uint256) {
    return _timesFor[_gameId].end;
  }

  function terminalOf(uint256 _gameId) external view override returns (IJBPaymentTerminal) {
    return _opsFor[_gameId].terminal;
  }

  function distributionLimit(uint256 _gameId) external view override returns (uint256) {
    return uint256(_opsFor[_gameId].distributionLimit);
  }

  function holdFeesDuring(uint256 _gameId) external view override returns (bool) {
    return _opsFor[_gameId].holdFees;
  }

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  /**
    @param _controller The controller with which new projects should be deployed. 
    @param _token The token that games deployed through this contract accept.
  */
  constructor(
    IJBController _controller,
    address _token
  ) {
    controller = _controller;
    token = _token;
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /**
    @notice
    Launches a new project with a Defifa data source attached.

    @param _delegateData Data necessary to fulfill the transaction to deploy a delegate.
    @param _launchProjectData Data necessary to fulfill the transaction to launch a project.

    @return gameId The ID of the newly configured game.
  */
  function launchGameWith(
    DefifaDelegateData calldata _delegateData,
    DefifaLaunchProjectData calldata _launchProjectData
  ) external override returns (uint256 gameId) {
    // Make sure the provided gameplay timestamps are sequential.
    if (
      _launchProjectData.tradeDeadline < _launchProjectData.start ||
      _launchProjectData.end < _launchProjectData.start ||
      _launchProjectData.end < _launchProjectData.tradeDeadline
    ) revert INVALID_GAME_CONFIGURATION();

    // Get the game ID, optimistically knowing it will be one greater than the current count.
    gameId = controller.projects().count() + 1;

    // Make sure the provided terminal accepts the same currency as this game is being played in.
    if (!_launchProjectData.terminal.acceptsToken(token, gameId)) revert UNEXPECTED_TERMINAL_CURRENCY();

    // Store the timestamps that'll define the game phases.
    _timesFor[gameId] = DefifaTimeData({
      start: _launchProjectData.start,
      tradeDeadline: _launchProjectData.tradeDeadline,
      end: _launchProjectData.end
    });

    // Store the terminal, distribution limit, and hold fees flag.
    _opsFor[gameId] = DefifaStoredOpsData({
      terminal:_launchProjectData.terminal,
      distributionLimit: _launchProjectData.distributionLimit,
      holdFees: _launchProjectData.holdFees
    });

    // Store the splits. They'll be used when queueing phase 2.
    JBGroupedSplits[] memory _groupedSplits = new JBGroupedSplits[](1);
    _groupedSplits[0] = JBGroupedSplits({group: gameId, splits: _launchProjectData.splits});
    // This contract must have SET_SPLITS operator permissions.
    controller.splitsStore().set(SPLIT_PROJECT_ID, SPLIT_DOMAIN, _groupedSplits);

    // Deploy the delegate contract.
    DefifaDelegate _delegate = new DefifaDelegate(
      gameId,
      controller.directory(),
      _delegateData.name,
      _delegateData.symbol,
      controller.fundingCycleStore(),
      _delegateData.baseUri,
      IJBTokenUriResolver(address(0)),
      _delegateData.contractUri,
      JB721PricingParams({
        tiers: _delegateData.tiers,
        currency: _launchProjectData.terminal.currencyForToken(token),
        decimals: _launchProjectData.terminal.decimalsForToken(token),
        prices: IJBPrices(address(0))
      }),
      _delegateData.store,
      JBTiered721Flags({
        lockReservedTokenChanges: false,
        lockVotingUnitChanges: false,
        lockManualMintingChanges: false
      })
    );

    // Queue the first phase of the game.
    _queuePhase1(_launchProjectData, address(_delegate));
  }

  /**
    @notice
    Queues the funding cycle that represents the next phase of the game, if it isn't queued already.

    @param _gameId The ID of the project having funding cycles reconfigured.

    @return configuration The configuration of the funding cycle that was successfully reconfigured.
  */
  function queueNextPhaseOf(uint256 _gameId)
    external
    override
    returns (uint256 configuration)
  {
    // Get the project's current funding cycle along with its metadata.
    (JBFundingCycle memory currentFundingCycle, JBFundingCycleMetadata memory metadata) = controller
      .currentFundingCycleOf(_gameId);

    // There are only 4 phases.
    if (currentFundingCycle.number >= 4) revert GAME_OVER();

    // Get the project's queued funding cycle.
    (JBFundingCycle memory queuedFundingCycle, ) = controller.queuedFundingCycleOf(_gameId);

    // Make sure the next game phase isn't already queued.
    if (currentFundingCycle.configuration != queuedFundingCycle.configuration)
      revert PHASE_ALREADY_QUEUED();

    // Queue the next phase of the game.
    if (currentFundingCycle.number == 1) return _queuePhase2(_gameId, metadata.dataSource);
    else if (currentFundingCycle.number == 2) return _queuePhase3(_gameId, metadata.dataSource);
    else return _queuePhase4(_gameId, metadata.dataSource);
  }

  //*********************************************************************//
  // ------------------------ internal functions ----------------------- //
  //*********************************************************************//

  /**
    @notice
    Launches a Defifa project with phase 1 configured.

    @param _launchProjectData Project data used for launching a 
    @param _dataSource The address of the Defifa data source.
  */
  function _queuePhase1(DefifaLaunchProjectData memory _launchProjectData, address _dataSource)
    internal
  {
    // Initialize the terminal array .
    IJBPaymentTerminal[] memory _terminals = new IJBPaymentTerminal[](1);
    _terminals[0] = _launchProjectData.terminal;

    // Launch the project with params for phase 1 of the game.
    controller.launchProjectFor(
      // Project is owned by this contract.
      address(this),
      _launchProjectData.projectMetadata,
      JBFundingCycleData ({
        duration: _launchProjectData.mintDuration,
        // Don't mint project tokens.
        weight: 0,
        discountRate: 0,
        ballot: IJBFundingCycleBallot(address(0))
      }),
      JBFundingCycleMetadata ({
        global: JBGlobalFundingCycleMetadata({
          allowSetTerminals: false,
          allowSetController: false,
          pauseTransfers: false
        }),
        reservedRate: 0,
        // Full refunds.
        redemptionRate: JBConstants.MAX_REDEMPTION_RATE,
        ballotRedemptionRate: JBConstants.MAX_REDEMPTION_RATE,
        pausePay: false,
        pauseDistributions: false,
        pauseRedeem: false,
        pauseBurn: false,
        allowMinting: false,
        allowTerminalMigration: false,
        allowControllerMigration: false,
        holdFees: _launchProjectData.holdFees,
        preferClaimedTokenOverride: false,
        useTotalOverflowForRedemptions: false,
        useDataSourceForPay: true,
        useDataSourceForRedeem: true,
        dataSource: _dataSource,
        metadata: 0
      }),
      _launchProjectData.mustStartAtOrAfter,
      new JBGroupedSplits[](0),
      new JBFundAccessConstraints[](0),
      _terminals,
      'Defifa game phase 1.'
    );
  }

  /**
    @notice
    Gets reconfiguration data for phase 2 of the game.

    @dev
    Phase 2 freezes the treasury and activates the pre-programmed distribution limit to the specified splits.

    @param _gameId The ID of the project that's being reconfigured.
    @param _dataSource The data source to use.

    @return configuration The configuration of the funding cycle that was successfully reconfigured.
  */
  function _queuePhase2(uint256 _gameId, address _dataSource)
    internal
    returns (uint256 configuration)
  {
    // Get a reference to the terminal being used by the project.
    DefifaStoredOpsData memory _ops = _opsFor[_gameId];

    // Set fund access constraints.
    JBFundAccessConstraints[] memory fundAccessConstraints = new JBFundAccessConstraints[](1);
    fundAccessConstraints[0] = JBFundAccessConstraints({
      terminal: _ops.terminal,
      token: token,
      distributionLimit: _ops.distributionLimit, 
      distributionLimitCurrency: _ops.terminal.currencyForToken(token),
      overflowAllowance: 0,
      overflowAllowanceCurrency: 0
    });

    // Fetch splits.
    JBSplit[] memory _splits =  controller.splitsStore().splitsOf(SPLIT_PROJECT_ID, SPLIT_DOMAIN, _gameId);

    // Make a group split for ETH payouts.
    JBGroupedSplits[] memory _groupedSplits = new JBGroupedSplits[](1);
    _groupedSplits[0] = JBGroupedSplits({group: JBSplitsGroups.ETH_PAYOUT, splits: _splits});

    // Get a reference to the time data.
    DefifaTimeData memory _times = _timesFor[_gameId];

    return
      controller.reconfigureFundingCyclesOf(
        _gameId,
        JBFundingCycleData ({
          duration: _times.tradeDeadline - _times.start,
          // Don't mint project tokens.
          weight: 0,
          discountRate: 0,
          ballot: IJBFundingCycleBallot(address(0))
        }),
        JBFundingCycleMetadata({
         global: JBGlobalFundingCycleMetadata({
            allowSetTerminals: false,
            allowSetController: false,
            pauseTransfers: false
          }),
          reservedRate: 0,
          redemptionRate: 0,
          ballotRedemptionRate: 0,
          // No more payments.
          pausePay: true,
          pauseDistributions: false,
          // No redemptions.
          pauseRedeem: true,
          pauseBurn: false,
          allowMinting: false,
          allowTerminalMigration: false,
          allowControllerMigration: false,
          holdFees: _ops.holdFees,
          preferClaimedTokenOverride: false,
          useTotalOverflowForRedemptions: false,
          useDataSourceForPay: true,
          useDataSourceForRedeem: true,
          dataSource: _dataSource,
          metadata: 0
        }),
        0, // mustStartAtOrAfter should be ASAP
         _groupedSplits,
        fundAccessConstraints,
        'Defifa game phase 2.'
      );
  }

  /**
    @notice
    Gets reconfiguration data for phase 3 of the game.

    @dev
    Phase 3 imposes a trade deadline. 

    @param _gameId The ID of the project that's being reconfigured.
    @param _dataSource The data source to use.

    @return configuration The configuration of the funding cycle that was successfully reconfigured.
  */
  function _queuePhase3(uint256 _gameId, address _dataSource) internal returns (uint256 configuration) {

    // Get a reference to the time data.
    DefifaTimeData memory _times = _timesFor[_gameId];

    return
      controller.reconfigureFundingCyclesOf(
        _gameId,
        JBFundingCycleData ({
          duration: _times.end - _times.tradeDeadline,
          // Don't mint project tokens.
          weight: 0,
          discountRate: 0,
          ballot: IJBFundingCycleBallot(address(0))
        }),
        JBFundingCycleMetadata({
         global: JBGlobalFundingCycleMetadata({
            allowSetTerminals: false,
            allowSetController: false,
            pauseTransfers: false
          }),
          reservedRate: 0,
          redemptionRate: 0,
          ballotRedemptionRate: 0,
          // No more payments.
          pausePay: true,
          pauseDistributions: false,
          // No redemptions.
          pauseRedeem: true,
          pauseBurn: false,
          allowMinting: false,
          allowTerminalMigration: false,
          allowControllerMigration: false,
          holdFees: false,
          preferClaimedTokenOverride: false,
          useTotalOverflowForRedemptions: false,
          useDataSourceForPay: true,
          useDataSourceForRedeem: true,
          dataSource: _dataSource,
          // Set a metadata of 1 to impose token non-transferability. 
          metadata: 1
        }),
        0, // mustStartAtOrAfter should be ASAP
        new JBGroupedSplits[](0),
        new JBFundAccessConstraints[](0),
        'Defifa game phase 3.'
      );
  }

  /**
    @notice
    Gets reconfiguration data for phase 4 of the game.

    @dev
    Phase 4 removes the trade deadline and open up redemptions.

    @param _gameId The ID of the project that's being reconfigured.
    @param _dataSource The data source to use.

    @return configuration The configuration of the funding cycle that was successfully reconfigured.
  */
  function _queuePhase4(uint256 _gameId, address _dataSource) internal returns (uint256 configuration) {
    return
      controller.reconfigureFundingCyclesOf(
        _gameId,
        JBFundingCycleData ({
          // No duration, lasts indefinately. 
          duration: 0,
          // Don't mint project tokens.
          weight: 0,
          discountRate: 0,
          ballot: IJBFundingCycleBallot(address(0))
        }),
        JBFundingCycleMetadata({
         global: JBGlobalFundingCycleMetadata({
            allowSetTerminals: false,
            allowSetController: false,
            pauseTransfers: false
          }),
          reservedRate: 0,
          // Linear redemptions.
          redemptionRate: JBConstants.MAX_REDEMPTION_RATE,
          ballotRedemptionRate: JBConstants.MAX_REDEMPTION_RATE,
          // No more payments.
          pausePay: true,
          pauseDistributions: false,
          // Redemptions allowed.
          pauseRedeem: false,
          pauseBurn: false,
          allowMinting: false,
          allowTerminalMigration: false,
          allowControllerMigration: false,
          holdFees: false,
          preferClaimedTokenOverride: false,
          useTotalOverflowForRedemptions: false,
          useDataSourceForPay: true,
          useDataSourceForRedeem: true,
          dataSource: _dataSource,
          // Transferability unlocked.
          metadata: 0
        }),
        0, // mustStartAtOrAfter should be ASAP
        new JBGroupedSplits[](0),
        new JBFundAccessConstraints[](0),
        'Defifa game phase 4.'
      );
  }
}
