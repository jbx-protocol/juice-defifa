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

        
    }

    function testReceiveVotingPower(uint8 nTiers, uint8 tier) public {
        vm.assume(nTiers >= tier);
        vm.assume(tier != 0);

        address _user = address(bytes20(keccak256('user')));

       (
           uint256 _projectId,
           DefifaTiered721Delegate _nft,
           DefifaGovernor _governor
       ) = createDefifaProject(uint256(nTiers));

        // User should have no voting power
        assertEq(
            _governor.getVotes(_user, block.number - 1),
            0
        );

        // fund user
        vm.deal(_user, 1 ether);

        // Build metadata to buy specific NFT
        uint16[] memory rawMetadata = new uint16[](1);
        rawMetadata[0] = uint16(tier); // reward tier
        bytes memory metadata = abi.encode(
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
           "",
           metadata
       );

       // Set the delegate as the user themselves
       vm.prank(_user);
       _nft.setTierDelegate(_user, uint256(tier));

       // Forward 1 block, user should receive all the voting power of the tier, as its the only NFT
       vm.roll(block.number + 1);
        assertEq(
          _governor.MAX_VOTING_POWER_TIER(),
          _governor.getVotes(_user, block.number - 1)
       );
    }

    // ----- internal helpers ------
    function createDefifaProject(uint256 nTiers) internal returns (uint256 projectId, DefifaTiered721Delegate nft, DefifaGovernor governor) {
        (
            JBDeployTiered721DelegateData memory NFTRewardDeployerData,
            JBLaunchProjectData memory launchProjectData
        ) = createData(nTiers);

        projectId = _jbController.projects().count() + 1;

        nft = new DefifaTiered721Delegate(
            projectId,
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

        launchProjectData.metadata.dataSource = address(nft);
        launchProjectData.metadata.useDataSourceForPay = true;
        launchProjectData.metadata.useDataSourceForRedeem = true;

        _jbController.launchProjectFor(
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

        

        governor = new DefifaGovernor(
            nft
        );
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
