// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBController.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBProjects.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBOperations.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycle.sol";
import "@jbx-protocol/juice-nft-rewards/contracts/JBTiered721Delegate.sol";
import "@jbx-protocol/juice-nft-rewards/contracts/interfaces/IJBTiered721DelegateProjectDeployer.sol";

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
contract DefifaProjectDeployer is IJBTiered721DelegateProjectDeployer {
    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    /**
    @notice
    The controller with which new projects should be deployed. 
  */
    IJBController public immutable override controller;

    /** 
    @notice
    The contract responsibile for deploying the delegate. 
  */
    IJBTiered721DelegateDeployer public immutable override delegateDeployer;

    /** 
    @notice
    Duration of the 1st fc to be verified when launching the fc. 
    */
    uint256 public immutable mintPhaseDuration;

    /** 
    @notice
    Start time of the 2nd fc to be verified when re-configuring the fc. 
    */
    uint256 public immutable startPhaseTimestamp;

    /** 
    @notice
    Start time of the 3rd fc to be verified when re-configuring the fc. 
    */
    uint256 public immutable tradePhaseTimestamp;

    /** 
    @notice
    Start time of the 4th fc to be verified when re-configuring the fc. 
    */
    uint256 public immutable endPhaseTimestamp;

    /** 
    @notice
    Distribution limit to be used in 2nd fc. 
    */
    uint256 public immutable distributionLimit;

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
        uint256 _mintPhaseDuration,
        uint256 _startPhaseTimestamp,
        uint256 _tradePhaseTimestamp,
        uint256 _endPhaseTimestamp,
        uint256 _distributionLimit
    ) {
        controller = _controller;
        delegateDeployer = _delegateDeployer;
        // checking in 1 block to avoidd duplication of similar checks
        if (_tradePhaseTimestamp < _startPhaseTimestamp ||  _endPhaseTimestamp < _startPhaseTimestamp || _endPhaseTimestamp < _tradePhaseTimestamp) 
          revert INVALID_FC_CONFIGURATION();
        mintPhaseDuration = _mintPhaseDuration;
        startPhaseTimestamp = _startPhaseTimestamp;
        tradePhaseTimestamp = _tradePhaseTimestamp;
        endPhaseTimestamp = _endPhaseTimestamp;
        distributionLimit = _distributionLimit;
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

    @return projectId The ID of the newly configured project.
  */
    function launchProjectFor(
        address _owner,
        JBDeployTiered721DelegateData calldata _deployTiered721DelegateData,
        JBLaunchProjectData memory _launchProjectData
    ) external override returns (uint256 projectId) {
        _owner; // avoid compiler warnings
        // Get the project ID, optimistically knowing it will be one greater than the current count.
        projectId = controller.projects().count() + 1;

        // Deploy the delegate contract.
        IJBTiered721Delegate _delegate = delegateDeployer.deployDelegateFor(projectId, _deployTiered721DelegateData);
        
        // ensuring no distribution limit
        if (_launchProjectData.fundAccessConstraints.length != 0)
          revert INVALID_FC_CONFIGURATION();

        // Set the delegate address as the data source of the provided metadata.
        _launchProjectData.metadata.dataSource = address(_delegate);

        // TODO: check if validating & reverting is more cheaper than these MSTORE's
        // Set the project to use the data source for its pay function.
        _launchProjectData.metadata.useDataSourceForPay = true;

        // Set the project to use the data source for its redeem function.
        _launchProjectData.metadata.useDataSourceForRedeem = true;

        // 100 % redemption rate
        _launchProjectData.metadata.redemptionRate = 10000;

        // set duration of 1st FC aka Mint Phase Duration
        _launchProjectData.data.duration = mintPhaseDuration;

        // Launch the project.
        _launchProjectFor(address(this), _launchProjectData);
    }

    /**
    @notice
    Launches funding cycle's for a project with a delegate attached.

    @dev
    Only a project owner or operator can launch its funding cycles.

    @param _projectId The ID of the project having funding cycles launched.
    @param _deployTiered721DelegateData Data necessary to fulfill the transaction to deploy a delegate.
    @param _launchFundingCyclesData Data necessary to fulfill the transaction to launch funding cycles for the project.

    @return configuration The configuration of the funding cycle that was successfully created.
  */
    function launchFundingCyclesFor(
        uint256 _projectId,
        JBDeployTiered721DelegateData calldata _deployTiered721DelegateData,
        JBLaunchFundingCyclesData memory _launchFundingCyclesData
    ) external override returns (uint256 configuration) {
        // Deploy the delegate contract.
        IJBTiered721Delegate _delegate = delegateDeployer.deployDelegateFor(
            _projectId,
            _deployTiered721DelegateData
        );

        // ensuring no distribution limit
        if (_launchFundingCyclesData.fundAccessConstraints.length != 0)
          revert INVALID_FC_CONFIGURATION();

        // Set the delegate address as the data source of the provided metadata.
        _launchFundingCyclesData.metadata.dataSource = address(_delegate);

        // TODO: check if validating & reverting is more cheaper than these MSTORE's
        // Set the project to use the data source for its pay function.
        _launchFundingCyclesData.metadata.useDataSourceForPay = true;

        // Set the project to use the data source for its redeem function.
        _launchFundingCyclesData.metadata.useDataSourceForRedeem = true;

        // 100 % redemption rate
        _launchFundingCyclesData.metadata.redemptionRate = 10000;

        // set duration of 1st FC aka Mint Phase Duration
        _launchFundingCyclesData.data.duration = mintPhaseDuration;

        // Launch the funding cycles.
        return _launchFundingCyclesFor(_projectId, _launchFundingCyclesData);
    }

    /**
    @notice
    Reconfigures funding cycles for a project with a delegate attached.

    @dev
    Only a project's owner or a designated operator can configure its funding cycles.

    @param _projectId The ID of the project having funding cycles reconfigured.
    @param _deployTiered721DelegateData Data necessary to fulfill the transaction to deploy a delegate.
    @param _reconfigureFundingCyclesData Data necessary to fulfill the transaction to reconfigure funding cycles for the project.

    @return configuration The configuration of the funding cycle that was successfully reconfigured.
  */
    function reconfigureFundingCyclesOf(
        uint256 _projectId,
        JBDeployTiered721DelegateData calldata _deployTiered721DelegateData,
        JBReconfigureFundingCyclesData memory _reconfigureFundingCyclesData
    ) external override returns (uint256 configuration) {
        // reference of current FC
        JBFundingCycle memory currentFundingCycle = _deployTiered721DelegateData.fundingCycleStore.currentOf(_projectId);

        // reference of queued FC
        JBFundingCycle memory queuedFundingCycle = _deployTiered721DelegateData.fundingCycleStore.queuedOf(_projectId);

        // ensuring no reconfigurations after fc 4
        if (currentFundingCycle.number > 3) 
          revert RECONFIGURATION_OVER();

        // ensuring reconfiguration is avoided if a reconfiguration already happened
        if (currentFundingCycle.configuration != queuedFundingCycle.configuration)
          revert FC_ALREADY_RECONFIGURED();

        // Deploy the delegate contract.
        IJBTiered721Delegate _delegate = delegateDeployer.deployDelegateFor(_projectId, _deployTiered721DelegateData);

        // Set the delegate address as the data source of the provided metadata.
        _reconfigureFundingCyclesData.metadata.dataSource = address(_delegate);
        
        // custom rules for each of the 3 reconfigurations
        if (currentFundingCycle.number == 1) {
            // ensuring only 1 element
            if (_reconfigureFundingCyclesData.fundAccessConstraints.length != 1)
              revert INVALID_FC_CONFIGURATION();
            
            // setting the distribution limit as the one set during deployment
            _reconfigureFundingCyclesData.fundAccessConstraints[0].distributionLimit = distributionLimit;

            // pausing payments
            _reconfigureFundingCyclesData.metadata.pausePay = true;

            // setting starting time
            _reconfigureFundingCyclesData.mustStartAtOrAfter = startPhaseTimestamp;

            // 0 redemption rate
            _reconfigureFundingCyclesData.metadata.redemptionRate = 0;

            // setting duration
            unchecked {
               _reconfigureFundingCyclesData.data.duration = tradePhaseTimestamp - startPhaseTimestamp;
            }
        } else if (currentFundingCycle.number == 2) {
            // ensuring no distribution limit
            if (_reconfigureFundingCyclesData.fundAccessConstraints.length != 0)
              revert INVALID_FC_CONFIGURATION();

            // pausing transfers
            _reconfigureFundingCyclesData.metadata.global.pauseTransfers = true;

            // pausing payments
            _reconfigureFundingCyclesData.metadata.pausePay = true;

            // setting starting time
            _reconfigureFundingCyclesData.mustStartAtOrAfter = tradePhaseTimestamp;

            // setting duration
            unchecked {
              _reconfigureFundingCyclesData.data.duration = endPhaseTimestamp - tradePhaseTimestamp;
            }

        } else {
            // ensuring no distribution limit
            if (_reconfigureFundingCyclesData.fundAccessConstraints.length != 0) 
              revert INVALID_FC_CONFIGURATION();
  
              // pausing payments
            _reconfigureFundingCyclesData.metadata.pausePay = true;

            // 100 % redemption rate
            _reconfigureFundingCyclesData.metadata.redemptionRate = 10000;

            // setting starting time
            _reconfigureFundingCyclesData.mustStartAtOrAfter = endPhaseTimestamp;
        }

        // Reconfigure the funding cycles.
        return
            _reconfigureFundingCyclesOf(
                _projectId,
                _reconfigureFundingCyclesData
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
