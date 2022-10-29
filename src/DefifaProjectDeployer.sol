// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBController.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBProjects.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBOperations.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycle.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundAccessConstraints.sol";
import "@jbx-protocol/juice-nft-rewards/contracts/JBTiered721Delegate.sol";
import "@jbx-protocol/juice-nft-rewards/contracts/interfaces/IJBTiered721DelegateProjectDeployer.sol";
import "./interfaces/IDefifaDeployer.sol";

//*********************************************************************//
// --------------------------- custom errors ------------------------- //
//*********************************************************************//
error INVALID_FC_CONFIGURATION();
error FC_ALREADY_RECONFIGURED();
error RECONFIGURATION_OVER();

/**
  @notice
  Deploys a defifa project.

  @dev
  Adheres to -
  IJBTiered721DelegateProjectDeployer: General interface for the generic controller methods in this contract that interacts with funding cycles and tokens according to the protocol's rules.
*/
contract DefifaProjectDeployer is IDefifaDeployer {
    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    uint256 public constant splitProjectId = 1;
    uint256 public constant domain = 1;

    /**
    @notice
    The controller with which new projects should be deployed. 
    */
    IJBController public immutable controller;

    /** 
    @notice
    The contract responsibile for deploying the delegate. 
    */
    IJBTiered721DelegateDeployer public immutable delegateDeployer;

    /** 
    @notice
    The contract responsibile for setting the splits for distribution. 
    */
    IJBSplitsStore immutable splitStore;

    /** 
    @notice
    Start time of the 2nd fc when re-configuring the fc. 
    */
    mapping(uint256 => uint256) public startPhaseTimestampForProject;

    /** 
    @notice
    Start time of the 3rd fc when re-configuring the fc. 
    */
    mapping(uint256 => uint256) public tradePhaseTimestampForProject;

    /** 
    @notice
    Start time of the 4th fc when re-configuring the fc. 
    */
    mapping(uint256 => uint256) public endPhaseTimestampForProject;

    /** 
    @notice
    Fund Access Constraint info to be used in 2nd fc. 
    */
    mapping(uint256 => FundAccessConstraintsConfig)
        public fundAccessConstraintOf;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /**
    @param _controller The controller with which new projects should be deployed. 
    @param _delegateDeployer The deployer of delegates.
  */
    constructor(
        IJBController _controller,
        IJBTiered721DelegateDeployer _delegateDeployer,
        IJBSplitsStore _splitStore
    ) {
        controller = _controller;
        delegateDeployer = _delegateDeployer;
        splitStore = _splitStore;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /** 
    @notice 
    Launches a new project with a tiered NFT rewards data source attached.

    @param _deployTiered721DelegateData Data necessary to fulfill the transaction to deploy a delegate.
    @param _launchProjectData Data necessary to fulfill the transaction to launch a project.
    @param _fcParams FC Timestamp params.
    @param _distributionParams distribution params.
    @param _splits split info that needs to be set.

    @return projectId The ID of the newly configured project.
  */
    function launchProjectFor(
        JBDeployTiered721DelegateData calldata _deployTiered721DelegateData,
        JBLaunchProjectData memory _launchProjectData,
        FCParams calldata _fcParams,
        DistributionParams calldata _distributionParams,
        JBSplit[] calldata _splits
    ) external override returns (uint256 projectId) {
        // checking in 1 block to avoidd duplication of similar checks
        if (
            _fcParams._tradePhaseTimestamp < _fcParams._startPhaseTimestamp ||
            _fcParams._endPhaseTimestamp < _fcParams._startPhaseTimestamp ||
            _fcParams._endPhaseTimestamp < _fcParams._tradePhaseTimestamp
        ) revert INVALID_FC_CONFIGURATION();

        // ensuring no distribution limit
        if (_launchProjectData.fundAccessConstraints.length != 0)
            revert INVALID_FC_CONFIGURATION();

        // ensuring the distributionsLimit for fc 2 is valid
        if (_distributionParams.distributionsLimit == 0)
            revert INVALID_FC_CONFIGURATION();

        // Get the project ID, optimistically knowing it will be one greater than the current count.
        projectId = controller.projects().count() + 1;
        
        // set reconfiguration config to be used later
        _setReconfigurationConfig(projectId, _fcParams, _distributionParams, _splits);

        // Deploy the delegate contract.
        IJBTiered721Delegate _delegate = delegateDeployer.deployDelegateFor(
            projectId,
            _deployTiered721DelegateData
        );

        // set 1st fc config
        _launchProjectData = _queuePhase1(_launchProjectData, _fcParams._mintPhaseDuration);

        // Set the delegate address as the data source of the provided metadata.
        _launchProjectData.metadata.dataSource = address(_delegate);

        // Launch the project.
        _launchProjectFor(address(this), _launchProjectData);
    }

    /**
    @notice
    Reconfigures funding cycles for a project with a delegate attached.

    @dev
    Only a project's owner or a designated operator can configure its funding cycles.

    @param _projectId The ID of the project having funding cycles reconfigured.

    @return configuration The configuration of the funding cycle that was successfully reconfigured.
  */
    function queueNextFundingCycleOf(
        uint256 _projectId
    ) external override returns (uint256 configuration) {

        // reference of current FC
        (JBFundingCycle memory currentFundingCycle, JBFundingCycleMetadata memory metadata) = controller.currentFundingCycleOf(_projectId);

        // reference of queued FC
        (JBFundingCycle memory queuedFundingCycle, ) = controller.queuedFundingCycleOf(_projectId);

        // ensuring no reconfigurations after fc 4
        if (currentFundingCycle.number > 3) revert RECONFIGURATION_OVER();

        // ensuring reconfiguration is avoided if a reconfiguration already happened
        if (
            currentFundingCycle.configuration !=
            queuedFundingCycle.configuration
        ) revert FC_ALREADY_RECONFIGURED();

        // validating the data source
        address _delegate = metadata.dataSource;

        // checking validity of delegate
        uint256 size;
        assembly {
            size := extcodesize(_delegate)
        }
        if (size == 0) {
            revert INVALID_FC_CONFIGURATION();
        }

        JBReconfigureFundingCyclesData memory reconfigureFundingCyclesData;

        // custom rules for each of the 3 reconfigurations
        if (currentFundingCycle.number == 1) {
            reconfigureFundingCyclesData = _queuePhase2(
                _projectId,
                currentFundingCycle,
                reconfigureFundingCyclesData
            );
        } else if (currentFundingCycle.number == 2) {
            reconfigureFundingCyclesData = _queuePhase3(
                _projectId,
                currentFundingCycle,
                reconfigureFundingCyclesData
            );
        } else {
            reconfigureFundingCyclesData = _queuePhase4(
                currentFundingCycle,
                reconfigureFundingCyclesData
            );
        }

        // set the existing data source for reconfiguration
        reconfigureFundingCyclesData.metadata.dataSource = address(_delegate);

        // Reconfigure the funding cycles.
        return
            _reconfigureFundingCyclesOf(
                _projectId,
                reconfigureFundingCyclesData
            );
    }

    //*********************************************************************//
    // ------------------------ internal functions ----------------------- //
    //*********************************************************************//

    /** 
    @notice
    Launches a project.

    @param _owner The address to set as the owner of the project. 
    @param _launchProjectData Data necessary to fulfill the transaction to launch the project.
  */
    function _launchProjectFor(
        address _owner,
        JBLaunchProjectData memory _launchProjectData
    ) internal {
        controller.launchProjectFor(
            _owner,
            _launchProjectData.projectMetadata,
            _launchProjectData.data,
            _launchProjectData.metadata,
            _launchProjectData.mustStartAtOrAfter,
            _launchProjectData.groupedSplits,
            _launchProjectData.fundAccessConstraints,
            _launchProjectData.terminals,
            _launchProjectData.memo
        );
    }

    /**
    @notice
    Launches funding cycles for a project.

    @param _projectId The ID of the project having funding cycles launched.
    @param _launchFundingCyclesData Data necessary to fulfill the transaction to launch funding cycles for the project.

    @return configuration The configuration of the funding cycle that was successfully created.
  */
    function _launchFundingCyclesFor(
        uint256 _projectId,
        JBLaunchFundingCyclesData memory _launchFundingCyclesData
    ) internal returns (uint256) {
        return
            controller.launchFundingCyclesFor(
                _projectId,
                _launchFundingCyclesData.data,
                _launchFundingCyclesData.metadata,
                _launchFundingCyclesData.mustStartAtOrAfter,
                _launchFundingCyclesData.groupedSplits,
                _launchFundingCyclesData.fundAccessConstraints,
                _launchFundingCyclesData.terminals,
                _launchFundingCyclesData.memo
            );
    }

    /**
    @notice
    Reconfigure funding cycles for a project.

    @param _projectId The ID of the project having funding cycles launched.
    @param _reconfigureFundingCyclesData Data necessary to fulfill the transaction to launch funding cycles for the project.

    @return The configuration of the funding cycle that was successfully reconfigured.
  */
    function _reconfigureFundingCyclesOf(
        uint256 _projectId,
        JBReconfigureFundingCyclesData memory _reconfigureFundingCyclesData
    ) internal returns (uint256) {
        return
            controller.reconfigureFundingCyclesOf(
                _projectId,
                _reconfigureFundingCyclesData.data,
                _reconfigureFundingCyclesData.metadata,
                _reconfigureFundingCyclesData.mustStartAtOrAfter,
                _reconfigureFundingCyclesData.groupedSplits,
                _reconfigureFundingCyclesData.fundAccessConstraints,
                _reconfigureFundingCyclesData.memo
            );
    }

    /** 
    @notice 
    Get fund access constraint parameters.
    @param _projectId Project ID to get the params of.

    @return distribution limit & distribution limit currency.
    */
    function _getConstraintParams(uint256 _projectId)
        internal
        view
        returns (
            uint256,
            uint256,
            IJBPaymentTerminal,
            address
        )
    {
        // Get a reference to the packed data.
        FundAccessConstraintsConfig
            memory fundAccessConstraintsConfig = fundAccessConstraintOf[
                _projectId
            ];
        // The limit is in bits 0 -231. The currency is in bits 232-255.
        return (
            uint256(
                uint232(fundAccessConstraintsConfig.packedDistributionLimit)
            ),
            fundAccessConstraintsConfig.packedDistributionLimit >> 232,
            fundAccessConstraintsConfig.terminal,
            fundAccessConstraintsConfig.token
        );
    }

    /** 
    @notice 
    Sets the reconfiguration config.
    @param _projectId Project ID to get the params of.
    @param _fcParams FC Timestamp params.
    @param _distributionParams distribution params.
    @param _splits split info that needs to be set.
    */
    function _setReconfigurationConfig(
        uint256 _projectId,
        FCParams calldata _fcParams,
        DistributionParams calldata _distributionParams,
        JBSplit[] calldata _splits
    ) internal {
        // save the timestamps so they can be fetched during reconfiguration
        startPhaseTimestampForProject[_projectId] = _fcParams
            ._startPhaseTimestamp;
        tradePhaseTimestampForProject[_projectId] = _fcParams
            ._tradePhaseTimestamp;
        endPhaseTimestampForProject[_projectId] = _fcParams._endPhaseTimestamp;

        // save the fund access constraint info so they can be fetched during reconfiguration
        fundAccessConstraintOf[_projectId] = FundAccessConstraintsConfig({
            terminal: _distributionParams.terminal,
            token: _distributionParams.token,
            packedDistributionLimit: _distributionParams.distributionsLimit |
                (_distributionParams.distributionLimitCurrency << 232)
        });

        // initialize group splits
        JBGroupedSplits[] memory _groupedSplits = new JBGroupedSplits[](1);
            _groupedSplits[0] = JBGroupedSplits({
                group: _projectId,
                splits: _splits
        });

        // set splits in split store
        splitStore.set(splitProjectId, domain, _groupedSplits);
    }


    /** 
    @notice 
    Sets launch params for fc 1.

    @param _launchProjectData launch fc data.
    @param _duration fc duration.

    @return _launchProjectData Launch config
    */
    function _queuePhase1(
        JBLaunchProjectData memory _launchProjectData,
        uint256 _duration
    ) internal pure returns (JBLaunchProjectData memory) {
        // Set the project to use the data source for its pay function.
        _launchProjectData.metadata.useDataSourceForPay = true;

        // Set the project to use the data source for its redeem function.
        _launchProjectData.metadata.useDataSourceForRedeem = true;

        // 100 % redemption rate
        _launchProjectData.metadata.redemptionRate = JBConstants.MAX_REDEMPTION_RATE;

        // set duration of 1st FC aka Mint Phase Duration
        _launchProjectData.data.duration = _duration;

        return _launchProjectData;
    }

    /** 
    @notice 
    Sets reconfiguration params for fc 2.

    @param _projectId Project ID.
    @param _currentFundingCycle current fc config.
    @param _reconfigureFundingCyclesData reconfiguration data.

    @return _reconfigureFundingCyclesData Re-Configuration config
    */
    function _queuePhase2(
        uint256 _projectId,
        JBFundingCycle memory _currentFundingCycle,
        JBReconfigureFundingCyclesData memory _reconfigureFundingCyclesData
    ) internal view returns (JBReconfigureFundingCyclesData memory) {
        // avoid stack too deep
        {
            // construct reconfiguration config for phase 2
            // set default funding cycle config
            JBFundingCycleData memory data = getDefaultJBFundingCycleData();

            // set funding cycle metadata config
            JBFundingCycleMetadata memory metadata = getDefaultJBFundingCycleMetadata();
            metadata.pausePay = true;

            // fetching constraint params
            (
                uint256 _distributionLimit,
                uint256 _distributionLimitCurrency,
                IJBPaymentTerminal _terminal,
                address _token
            ) = _getConstraintParams(_projectId);

            // set constraint params
            JBFundAccessConstraints[] memory fundAccessConstraints = new JBFundAccessConstraints[](1);
            fundAccessConstraints[0] = JBFundAccessConstraints({
                terminal: _terminal,
                token: _token,
                distributionLimit: _distributionLimit,
                distributionLimitCurrency: _distributionLimitCurrency,
                overflowAllowance: 0,
                overflowAllowanceCurrency: 0
            });

            // fetch splits
            JBSplit[] memory _splits = splitStore.splitsOf(splitProjectId, domain, _projectId);

            JBGroupedSplits[] memory _groupedSplits = new JBGroupedSplits[](1);
            _groupedSplits[0] = JBGroupedSplits({
                group: _projectId,
                splits: _splits
            });

            _reconfigureFundingCyclesData = JBReconfigureFundingCyclesData({
                data: data,
                metadata: metadata,
                mustStartAtOrAfter: _currentFundingCycle.start + _currentFundingCycle.duration,
                groupedSplits: _groupedSplits,
                fundAccessConstraints: fundAccessConstraints,
                memo: "reconfigure fc"
            });
        }

        // setting duration
        unchecked {
            _reconfigureFundingCyclesData.data.duration =
                tradePhaseTimestampForProject[_projectId] -
                startPhaseTimestampForProject[_projectId];
        }
        return _reconfigureFundingCyclesData;
    }

    /** 
    @notice 
    Sets reconfiguration params for fc 3.

    @param _projectId Project ID.
    @param _currentFundingCycle current fc config.
    @param _reconfigureFundingCyclesData reconfiguration data.

    @return _reconfigureFundingCyclesData Re-Configuration config
    */
    function _queuePhase3(
        uint256 _projectId,
        JBFundingCycle memory _currentFundingCycle,
        JBReconfigureFundingCyclesData memory _reconfigureFundingCyclesData
    ) internal view returns (JBReconfigureFundingCyclesData memory) {
        // construct reconfiguration config for phase 3
        // set default funding cycle config
        JBFundingCycleData memory data = getDefaultJBFundingCycleData();

        // set funding cycle metadata config
        JBFundingCycleMetadata memory metadata = getDefaultJBFundingCycleMetadata();
        metadata.pausePay = true;
        metadata.metadata = 1;

        // initialize empty fund constraints
        JBFundAccessConstraints[] memory fundAccessConstraints = new JBFundAccessConstraints[](0);

        // initialize empty group split
        JBGroupedSplits[] memory splitGroups = new JBGroupedSplits[](0);

        _reconfigureFundingCyclesData = JBReconfigureFundingCyclesData({
            data: data,
            metadata: metadata,
            mustStartAtOrAfter: _currentFundingCycle.start + _currentFundingCycle.duration,
            groupedSplits: splitGroups,
            fundAccessConstraints: fundAccessConstraints,
            memo: "reconfigure fc"
        });

        // setting duration
        unchecked {
            _reconfigureFundingCyclesData.data.duration =
                endPhaseTimestampForProject[_projectId] -
                tradePhaseTimestampForProject[_projectId];
        }

        return _reconfigureFundingCyclesData;
    }

    /** 
    @notice 
    Sets reconfiguration params for fc 4.
    @param _currentFundingCycle current fc config.
    @param _reconfigureFundingCyclesData reconfiguration data.

    @return _reconfigureFundingCyclesData Re-Configuration config    */
    function _queuePhase4(
        JBFundingCycle memory _currentFundingCycle,
        JBReconfigureFundingCyclesData memory _reconfigureFundingCyclesData
    ) internal pure returns (JBReconfigureFundingCyclesData memory) {
        // construct reconfiguration config for phase 3
        // set default funding cycle config
        JBFundingCycleData memory data = getDefaultJBFundingCycleData();

        // set funding cycle metadata config
        JBFundingCycleMetadata memory metadata = getDefaultJBFundingCycleMetadata();
        metadata.pausePay = true;
        metadata.redemptionRate = JBConstants.MAX_REDEMPTION_RATE;

        // initialize empty fund constraints
        JBFundAccessConstraints[] memory fundAccessConstraints = new JBFundAccessConstraints[](0);

        // initialize empty group split
        JBGroupedSplits[] memory splitGroups = new JBGroupedSplits[](0);

        _reconfigureFundingCyclesData = JBReconfigureFundingCyclesData({
            data: data,
            metadata: metadata,
            mustStartAtOrAfter: _currentFundingCycle.start + _currentFundingCycle.duration,
            groupedSplits: splitGroups,
            fundAccessConstraints: fundAccessConstraints,
            memo: "reconfigure fc"
        });
        return _reconfigureFundingCyclesData;
    }

    /** 
    @notice 
    Returns default funding cycle data.
    */
    function getDefaultJBFundingCycleData() internal pure returns (JBFundingCycleData memory) {
        return JBFundingCycleData({
            duration: 0,
            weight: 0,
            discountRate: 0,
            ballot: IJBFundingCycleBallot(address(0))
        });
    }

    /** 
    @notice 
    Returns default funding cycle metadata.
    */
    function getDefaultJBFundingCycleMetadata() internal pure returns (JBFundingCycleMetadata memory) {
        return JBFundingCycleMetadata({
            global: JBGlobalFundingCycleMetadata({
                allowSetTerminals: false,
                allowSetController: false,
                pauseTransfers: false
            }),
            reservedRate: 0,
            redemptionRate: 0,
            ballotRedemptionRate: 0,
            pausePay: false,
            pauseDistributions: false,
            pauseRedeem: false,
            pauseBurn: false,
            allowMinting: false,
            allowTerminalMigration: false,
            allowControllerMigration: false,
            holdFees: false,
            preferClaimedTokenOverride: false,
            useTotalOverflowForRedemptions: false,
            useDataSourceForPay: false,
            useDataSourceForRedeem: false,
            dataSource: address(0),
            metadata: 0
        });
    }
}
