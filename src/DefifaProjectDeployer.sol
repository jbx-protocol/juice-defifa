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
    mapping(uint256 => FundAccessConstraintsConfig) public fundAccessConstraintOf;

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
    // -------------------------- internal methods ---------------------------- //
    //*********************************************************************//

    /** 
    @notice 
    Get fund access constraint parameters.
    @param _projectId Project ID to get the params of.

    @return distribution limit & distribution limit currency.
    */
    function getConstraintParams(uint256 _projectId)
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
    function setReconfigurationConfig(
      uint256 _projectId,
      FCParams calldata _fcParams,
      SplitConfig calldata _splitParams,
      DistributionParams calldata _distributionParams,
      JBGroupedSplits[] calldata _groupedSplits ) internal {
        // set splits in split store
        splitStore.set(_projectId, _splitParams.domain, _groupedSplits);

        // save the split config so splits can be fetched during reconfiguration
        splitConfigOf[_projectId] = SplitConfig({
            group: _splitParams.group,
            domain: _splitParams.domain
        });

         // save the timestamps so they can be fetched during reconfiguration
        startPhaseTimestampForProject[_projectId] = _fcParams._startPhaseTimestamp;
        tradePhaseTimestampForProject[_projectId] = _fcParams._tradePhaseTimestamp;
        endPhaseTimestampForProject[_projectId] = _fcParams._endPhaseTimestamp;

         // save the fund access constraint info so they can be fetched during reconfiguration
        fundAccessConstraintOf[_projectId] = FundAccessConstraintsConfig({
            terminal: _distributionParams.terminal,
            token: _distributionParams.token,
            packedDistributionLimit: _distributionParams.distributionsLimit | (_distributionParams.distributionLimitCurrency << 232)
        });
      }

    /** 
    @notice 
    Generate fc recongiration params.
    @param _projectId Project ID to get the params of.

    @return .fc recongiration params
    */
    function generateReconfigurationData(uint256 _projectId)
        internal
        pure
        returns (JBReconfigureFundingCyclesData memory)
    {
        JBFundingCycleData memory data = JBFundingCycleData({
            duration: 0,
            weight: 1 ether, // TODO we can probably set it to 0 in this context ?
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
                mustStartAtOrAfter: 0,
                groupedSplits: splitGroups,
                fundAccessConstraints: fundAccessConstraints,
                memo: "reconfigure fc"
            });
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /** 
    @notice 
    Launches a new project with a tiered NFT rewards data source attached.

    @param _owner The address to set as the owner of the project. The project ERC-721 will be owned by this address.
    @param _deployTiered721DelegateData Data necessary to fulfill the transaction to deploy a delegate.
    @param _launchProjectData Data necessary to fulfill the transaction to launch a project.
    @param _fcParams FC Timestamp params.
    @param _splitParams Splits params.
    @param _distributionParams distribution params.
    @param _groupedSplits group splits for distribution.

    @return projectId The ID of the newly configured project.
  */
    function launchProjectFor(
        address _owner,
        JBDeployTiered721DelegateData calldata _deployTiered721DelegateData,
        JBLaunchProjectData memory _launchProjectData,
        FCParams calldata _fcParams,
        SplitConfig calldata _splitParams,
        DistributionParams calldata _distributionParams,
        JBGroupedSplits[] calldata _groupedSplits
    ) external override returns (uint256 projectId) {
        _owner; // avoid compiler warnings

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

        setReconfigurationConfig(
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

        // Deploy the delegate contract.
        IJBTiered721Delegate _delegate = delegateDeployer.deployDelegateFor(
            _projectId,
            _deployTiered721DelegateData
        );

        JBReconfigureFundingCyclesData memory reconfigureFundingCyclesData;
        // prevent stack too deep
        {
            reconfigureFundingCyclesData = generateReconfigurationData(
                _projectId
            );
        }
        reconfigureFundingCyclesData.metadata.dataSource = address(_delegate);
        // custom rules for each of the 3 reconfigurations
        if (currentFundingCycle.number == 1) {
          uint256 _startPhaseTimestamp;
          {
            (
                uint256 distributionLimit,
                uint256 distributionLimitCurrency,
                IJBPaymentTerminal terminal,
                address token
            ) = getConstraintParams(_projectId);

            // setting the fund access constraints
            reconfigureFundingCyclesData.fundAccessConstraints[0].distributionLimit = distributionLimit;

            reconfigureFundingCyclesData.fundAccessConstraints[0].distributionLimitCurrency = distributionLimitCurrency;

            reconfigureFundingCyclesData.fundAccessConstraints[0].terminal = terminal;
            
            reconfigureFundingCyclesData.fundAccessConstraints[0].token = token;

            // fetch the splits from split store and set it
            SplitConfig memory splitConfig = splitConfigOf[_projectId];
            JBSplit[] memory splits = splitStore.splitsOf(
                _projectId,
                splitConfig.domain,
                splitConfig.group
            );
            reconfigureFundingCyclesData.groupedSplits[0].group = splitConfig.group;

            reconfigureFundingCyclesData.groupedSplits[0].splits = splits;

            // pausing payments
            reconfigureFundingCyclesData.metadata.pausePay = true;

            // local reference for startPhaseTimestamp to avoid a SLOAD
            _startPhaseTimestamp = startPhaseTimestampForProject[_projectId];

            // setting starting time
            reconfigureFundingCyclesData.mustStartAtOrAfter = _startPhaseTimestamp;

            // 0 redemption rate
            reconfigureFundingCyclesData.metadata.redemptionRate = 0;
          }
            // setting duration
            unchecked {
                reconfigureFundingCyclesData.data.duration =
                    tradePhaseTimestampForProject[_projectId] -
                    _startPhaseTimestamp;
            }
        } else if (currentFundingCycle.number == 2) {
            // pausing transfers
            reconfigureFundingCyclesData.metadata.global.pauseTransfers = true;

            // pausing payments
            reconfigureFundingCyclesData.metadata.pausePay = true;

            // local reference for tradePhaseTimestamp to avoid a SLOAD
            uint256 _tradePhaseTimestamp = tradePhaseTimestampForProject[_projectId];

            // setting starting time
            reconfigureFundingCyclesData.mustStartAtOrAfter = _tradePhaseTimestamp;

            // setting duration
            unchecked {
                reconfigureFundingCyclesData.data.duration =
                    endPhaseTimestampForProject[_projectId] -
                    _tradePhaseTimestamp;
            }
        } else {
            // pausing payments
            reconfigureFundingCyclesData.metadata.pausePay = true;

            // 100 % redemption rate
            reconfigureFundingCyclesData.metadata.redemptionRate = 10000;

            // setting starting time
            reconfigureFundingCyclesData.mustStartAtOrAfter = endPhaseTimestampForProject[_projectId];
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
}
