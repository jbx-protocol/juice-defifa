// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/DefifaGovernor.sol";
import "../src/DefifaTiered721Delegate.sol";

import "@jbx-protocol/juice-nft-rewards/contracts/forge-test/utils/TestBaseWorkflow.sol";
import "@jbx-protocol/juice-nft-rewards/contracts/structs/JBDeployTiered721DelegateData.sol";
import "@jbx-protocol/juice-nft-rewards/contracts/structs/JBLaunchProjectData.sol";
import "@jbx-protocol/juice-nft-rewards/contracts/JBTiered721DelegateStore.sol";

contract DefifaGovernorTest is TestBaseWorkflow {
    DefifaGovernor public governor;
    DefifaTiered721Delegate public nfts;

    address projectOwner = address(bytes20(keccak256('projectOwner')));

    function setUp() virtual override public {
        super.setUp();

        (
            JBDeployTiered721DelegateData memory NFTRewardDeployerData,
            JBLaunchProjectData memory launchProjectData
        ) = createData();

        uint256 _projectId = _jbController.launchProjectFor(
            projectOwner, // owner
            launchProjectData.projectMetadata,
            launchProjectData.data,
            launchProjectData.metadata,
            launchProjectData.mustStartAtOrAfter,
            launchProjectData.groupedSplits,
            launchProjectData.fundAccessConstraints,
            launchProjectData.terminals,
            launchProjectData.memo
        );

        nfts = new DefifaTiered721Delegate(
            _projectId,
            NFTRewardDeployerData.directory,
            NFTRewardDeployerData.name,
            NFTRewardDeployerData.symbol,
            NFTRewardDeployerData.fundingCycleStore,
            NFTRewardDeployerData.baseUri,
            NFTRewardDeployerData.tokenUriResolver,
            NFTRewardDeployerData.contractUri,
            NFTRewardDeployerData.tiers,
            NFTRewardDeployerData.store,
            NFTRewardDeployerData.flags
        );

        governor = new DefifaGovernor(
            nfts
        );
    }

    function testSetup() public {
        governor.proposalThreshold();
    }

    // ----- internal helpers ------
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
    
    function createData()
        internal
        returns (
            JBDeployTiered721DelegateData memory NFTRewardDeployerData,
            JBLaunchProjectData memory launchProjectData
        )
    {
        JB721TierParams[] memory tierParams = new JB721TierParams[](10);

        for (uint256 i; i < 10; i++) {
            tierParams[i] = JB721TierParams({
                contributionFloor: uint80((i + 1) * 10),
                lockedUntil: uint48(0),
                initialQuantity: uint40(10),
                votingUnits: uint16((i + 1) * 10),
                reservedRate: uint16(JBConstants.MAX_RESERVED_RATE),
                reservedTokenBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[i],
                shouldUseBeneficiaryAsDefault: false
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
            tiers: tierParams,
            reservedTokenBeneficiary: reserveBeneficiary,
            store: new JBTiered721DelegateStore(),
            flags: JBTiered721Flags({
                lockReservedTokenChanges: false,
                lockVotingUnitChanges: false
            })
        });

        launchProjectData = JBLaunchProjectData({
            projectMetadata: _projectMetadata,
            data: _data,
            metadata: _metadata,
            mustStartAtOrAfter: 0,
            groupedSplits: _groupedSplits,
            fundAccessConstraints: _fundAccessConstraints,
            terminals: _terminals,
            memo: ""
        });
    }
}
