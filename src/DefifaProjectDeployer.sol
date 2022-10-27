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

    /** 
    @notice
    Split config to be used in 2nd fc. 
    */
    mapping(uint256 => SplitConfig) public splitConfigOf;

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
    @param _splitParams Splits params.
    @param _distributionParams distribution params.
    @param _groupedSplits group splits for distribution.

    @return projectId The ID of the newly configured project.
  */
    function launchProjectFor(
        JBDeployTiered721DelegateData calldata _deployTiered721DelegateData,
        JBLaunchProjectData memory _launchProjectData,
        FCParams calldata _fcParams,
        SplitConfig calldata _splitParams,
        DistributionParams calldata _distributionParams,
        JBGroupedSplits[] calldata _groupedSplits
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

        _setReconfigurationConfig(
            projectId,
            _fcParams,
            _splitParams,
            _distributionParams,
            _groupedSplits
        );

        // Deploy the delegate contract.
        IJBTiered721Delegate _delegate = delegateDeployer.deployDelegateFor(
            projectId,
            _deployTiered721DelegateData
        );

        // Set the delegate address as the data source of the provided metadata.
        _launchProjectData.metadata.dataSource = address(_delegate);

        // Set the project to use the data source for its pay function.
        _launchProjectData.metadata.useDataSourceForPay = true;

        // Set the project to use the data source for its redeem function.
        _launchProjectData.metadata.useDataSourceForRedeem = true;

        // 100 % redemption rate
        _launchProjectData.metadata.redemptionRate = 10000;

        // set duration of 1st FC aka Mint Phase Duration
        _launchProjectData.data.duration = _fcParams._mintPhaseDuration;

        // Launch the project.
        _launchProjectFor(address(this), _launchProjectData);
    }

    /**
    @notice
    Reconfigures funding cycles for a project with a delegate attached.

    @dev
    Only a project's owner or a designated operator can configure its funding cycles.

    @param _projectId The ID of the project having funding cycles reconfigured.
    @param _deployTiered721DelegateData Data necessary to fulfill the transaction to deploy a delegate.

    @return configuration The configuration of the funding cycle that was successfully reconfigured.
  */
    function queueNextFundingCycleOf(
        uint256 _projectId,
        JBDeployTiered721DelegateData calldata _deployTiered721DelegateData
    ) external override returns (uint256 configuration) {
        // reference of current FC
        JBFundingCycle memory currentFundingCycle = _deployTiered721DelegateData
            .fundingCycleStore
            .currentOf(_projectId);

        // reference of queued FC
        JBFundingCycle memory queuedFundingCycle = _deployTiered721DelegateData
            .fundingCycleStore
            .queuedOf(_projectId);

        // ensuring no reconfigurations after fc 4
        if (currentFundingCycle.number > 3) revert RECONFIGURATION_OVER();

        // ensuring reconfiguration is avoided if a reconfiguration already happened
        if (
            currentFundingCycle.configuration !=
            queuedFundingCycle.configuration
        ) revert FC_ALREADY_RECONFIGURED();

        // validating the data source
        (, JBFundingCycleMetadata memory metadata) = controller
            .getFundingCycleOf(_projectId, currentFundingCycle.configuration);
        address _delegate = metadata.dataSource;
        uint256 size;
        assembly {
            size := extcodesize(_delegate)
        }
        if (size == 0) {
            revert INVALID_FC_CONFIGURATION();
        }

        JBReconfigureFundingCyclesData memory reconfigureFundingCyclesData;
        // prevent stack too deep
        {
            reconfigureFundingCyclesData = _generateReconfigurationData(
                _projectId,
                currentFundingCycle
            );
        }
        // set the existing data source for reconfiguration
        reconfigureFundingCyclesData.metadata.dataSource = address(_delegate);

        // custom rules for each of the 3 reconfigurations
        if (currentFundingCycle.number == 1) {
            _queuePhase2(_projectId, reconfigureFundingCyclesData);
        } else if (currentFundingCycle.number == 2) {
            _queuePhase3(_projectId, reconfigureFundingCyclesData);
        } else {
            _queuePhase4(reconfigureFundingCyclesData);
        }

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
    @param _splitParams Splits params.
    @param _distributionParams distribution params.
    @param _groupedSplits group splits for distribution.
    */
    function _setReconfigurationConfig(
        uint256 _projectId,
        FCParams calldata _fcParams,
        SplitConfig calldata _splitParams,
        DistributionParams calldata _distributionParams,
        JBGroupedSplits[] calldata _groupedSplits
    ) internal {
        // set splits in split store
        splitStore.set(_projectId, _splitParams.domain, _groupedSplits);

        // save the split config so splits can be fetched during reconfiguration
        splitConfigOf[_projectId] = SplitConfig({
            group: _splitParams.group,
            domain: _splitParams.domain
        });

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
    }

    /** 
    @notice 
    Generate fc recongiration params.
    @param _projectId Project ID to get the params of.

    @return .fc recongiration params
    */
    function _generateReconfigurationData(
        uint256 _projectId,
        JBFundingCycle memory _currentFundingCycle
    ) internal pure returns (JBReconfigureFundingCyclesData memory) {
        JBFundingCycleData memory data = JBFundingCycleData({
            duration: 0,
            weight: 0,
            discountRate: 0,
            ballot: IJBFundingCycleBallot(address(0))
        });

        JBFundingCycleMetadata memory metadata = JBFundingCycleMetadata({
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

        JBFundAccessConstraints[]
            memory fundAccessConstraints = new JBFundAccessConstraints[](1);
        fundAccessConstraints[0] = JBFundAccessConstraints({
            terminal: IJBPaymentTerminal(address(0)),
            token: address(0),
            distributionLimit: 0,
            distributionLimitCurrency: 0,
            overflowAllowance: 0,
            overflowAllowanceCurrency: 0
        });

        JBSplit[] memory defaultSplits = new JBSplit[](1);
        defaultSplits[0] = JBSplit({
            preferClaimed: false,
            preferAddToBalance: false,
            percent: 0,
            projectId: _projectId,
            beneficiary: payable(address(0)),
            lockedUntil: 0,
            allocator: IJBSplitAllocator(address(0))
        });

        JBGroupedSplits[] memory splitGroups = new JBGroupedSplits[](1);
        splitGroups[0] = JBGroupedSplits({group: 0, splits: defaultSplits});

        return
            JBReconfigureFundingCyclesData({
                data: data,
                metadata: metadata,
                mustStartAtOrAfter: _currentFundingCycle.start +
                    _currentFundingCycle.duration,
                groupedSplits: splitGroups,
                fundAccessConstraints: fundAccessConstraints,
                memo: "reconfigure fc"
            });
    }

    /** 
    @notice 
    Sets reconfiguration params for fc 2.

    @param _projectId Project ID.
    @param _reconfigureFundingCyclesData reconfiguration data.
    */
    function _queuePhase2(
        uint256 _projectId,
        JBReconfigureFundingCyclesData memory _reconfigureFundingCyclesData
    ) internal view {
        (
            uint256 distributionLimit,
            uint256 distributionLimitCurrency,
            IJBPaymentTerminal terminal,
            address token
        ) = _getConstraintParams(_projectId);

        // setting the fund access constraints
        _reconfigureFundingCyclesData
            .fundAccessConstraints[0]
            .distributionLimit = distributionLimit;

        _reconfigureFundingCyclesData
            .fundAccessConstraints[0]
            .distributionLimitCurrency = distributionLimitCurrency;

        _reconfigureFundingCyclesData
            .fundAccessConstraints[0]
            .terminal = terminal;

        _reconfigureFundingCyclesData.fundAccessConstraints[0].token = token;

        // fetch the splits from split store and set it
        SplitConfig memory splitConfig = splitConfigOf[_projectId];
        JBSplit[] memory splits = splitStore.splitsOf(
            _projectId,
            splitConfig.domain,
            splitConfig.group
        );
        _reconfigureFundingCyclesData.groupedSplits[0].group = splitConfig
            .group;

        _reconfigureFundingCyclesData.groupedSplits[0].splits = splits;

        // pausing payments
        _reconfigureFundingCyclesData.metadata.pausePay = true;

        // 0 redemption rate
        _reconfigureFundingCyclesData.metadata.redemptionRate = 0;
        // setting duration
        unchecked {
            _reconfigureFundingCyclesData.data.duration =
                tradePhaseTimestampForProject[_projectId] -
                startPhaseTimestampForProject[_projectId];
        }
    }

    /** 
    @notice 
    Sets reconfiguration params for fc 3.

    @param _projectId Project ID.
    @param _reconfigureFundingCyclesData reconfiguration data.
    */
    function _queuePhase3(
        uint256 _projectId,
        JBReconfigureFundingCyclesData memory _reconfigureFundingCyclesData
    ) internal view {
        // pausing transfers
        _reconfigureFundingCyclesData.metadata.metadata = 1;

        // pausing payments
        _reconfigureFundingCyclesData.metadata.pausePay = true;

        // setting duration
        unchecked {
            _reconfigureFundingCyclesData.data.duration =
                endPhaseTimestampForProject[_projectId] -
                tradePhaseTimestampForProject[_projectId];
        }
    }

    /** 
    @notice 
    Sets reconfiguration params for fc 4.
    @param _reconfigureFundingCyclesData reconfiguration data.
    */
    function _queuePhase4(
        JBReconfigureFundingCyclesData memory _reconfigureFundingCyclesData
    ) internal pure {
        // pausing payments
        _reconfigureFundingCyclesData.metadata.pausePay = true;

        // 100 % redemption rate
        _reconfigureFundingCyclesData.metadata.redemptionRate = 10000;
    }
}
