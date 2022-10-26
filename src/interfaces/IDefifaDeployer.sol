// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBController.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBProjects.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBProjectMetadata.sol';
import '@jbx-protocol/juice-nft-rewards/contracts/structs/JBDeployTiered721DelegateData.sol';
import '@jbx-protocol/juice-nft-rewards/contracts/structs/JBLaunchProjectData.sol';
import '@jbx-protocol/juice-nft-rewards/contracts/structs/JBReconfigureFundingCyclesData.sol';
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundAccessConstraints.sol";

interface IDefifaDeployer {
    function launchProjectFor(
        address _owner,
        JBDeployTiered721DelegateData calldata _deployTiered721DelegateData,
        JBLaunchProjectData memory _launchProjectData,
        FCParams calldata fcParams,
        SplitConfig calldata splitParams,
        DistributionParams calldata distributionParams,
        JBGroupedSplits[] calldata _groupedSplits
    ) external returns (uint256 projectId);

    function queueNextFundingCycleOf(
        uint256 _projectId,
        JBDeployTiered721DelegateData calldata _deployTieredNFTRewardDelegateData
    ) external returns (uint256 configuration);
}

struct SplitConfig {
    uint256 group;
    uint256 domain;
}

struct FundAccessConstraintsConfig {
     IJBPaymentTerminal terminal;
     address token;
     uint256 packedDistributionLimit;
}

struct FCParams {
        uint256 _mintPhaseDuration;
        uint256 _startPhaseTimestamp;
        uint256 _tradePhaseTimestamp;
        uint256 _endPhaseTimestamp;
}

struct DistributionParams {
     uint256 distributionsLimit;
     uint256 distributionLimitCurrency;
     IJBPaymentTerminal terminal;
     address token;
}
