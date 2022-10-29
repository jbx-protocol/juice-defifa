// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "prb-math/PRBMath.sol";

import "@jbx-protocol/juice-nft-rewards/contracts/JBTiered721Delegate.sol";
import "@jbx-protocol/juice-nft-rewards/contracts/JB721TieredGovernance.sol";

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

// errors
error PROPOSAL_CREATION_THRESHOLD_NOT_REACHED_YET();

contract DefifaGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple
{
   // The max voting power 1 tier has if everyone votes
    uint256 public constant MAX_VOTING_POWER_TIER = 1_000_000_000;

   // datasource
    IJBTiered721Delegate jbTieredRewards;

    // The datasource for votingpower
    IJB721TieredGovernance jbTieredGovernance;

    // proposal creation threshold time
    uint256 public immutable proposalCreationThreshold;

    constructor(
        IJBTiered721Delegate _jbTieredRewards,
        IJB721TieredGovernance _jbTieredGovernance,
        uint256 _proposalCreationThreshold
    )
        Governor("DefifaGovernor")
        GovernorSettings(
            1, /* 1 block */
            45818, /* 1 week */
            0
        )
    {
        jbTieredRewards = _jbTieredRewards;
        jbTieredGovernance = _jbTieredGovernance;
        proposalCreationThreshold = _proposalCreationThreshold;
    }

    /**
     * Get the voting weights for specific tiers
     */
    function _getVotes(
        address account,
        uint256 blockNumber,
        bytes memory params
    ) internal view virtual override(Governor) returns (uint256 votingPower) {
        // Decode the bytes into the tier_ids
        uint256[] memory _tiers = abi.decode(params, (uint[]));
        uint256 _tiers_length = _tiers.length;

        // Loop over all tiers gathering the voting share of the user
        for (uint256 _i; _i < _tiers_length; ) {
            uint256 _tierVotingPower = jbTieredGovernance.getPastTierVotes(
                account,
                _tiers[_i],
                blockNumber
            );

            unchecked {
                if (_tierVotingPower != 0){
                    votingPower += PRBMath.mulDiv(
                        _tierVotingPower,
                        MAX_VOTING_POWER_TIER,
                        jbTieredGovernance.getPastTierTotalVotes(
                            _tiers[_i],
                            blockNumber
                        )
                    );
                }

                ++_i;
            }
        }
    }

    /**
     * @dev See {IGovernor-getVotesWithParams}.
     * reverting to avoid passsing of duplicate tier id's in params
     */
    function getVotesWithParams(
        address account,
        uint256 blockNumber,
        bytes memory params
    ) public pure override returns (uint256) {
        revert("use getVotes");
    }

    /**
     * @dev Default additional encoded parameters used by castVote methods that don't include them
     */
    function _defaultParams()
        internal
        view
        virtual
        override
        returns (bytes memory)
    {
       // TODO: should we do this on every time or should we just store this, what is cheaper...
       uint256 _count = jbTieredRewards.store().maxTierIdOf(address(jbTieredRewards));
       uint256[] memory _ids = new uint256[](_count);

      // Add all tiers to the array
      for(uint256 _i; _i < _count;){
          // Tiers start counting from 1
         _ids[_i] = _i + 1;

         unchecked{ 
            ++_i;
         }
      }

        return abi.encode(_ids);
    }

    // Overrides we have to do

    function votingDelay()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernor)
        returns (uint256)
    {
        // TODO: I just picked some random value for now, decide what a appropriate quarum should be
        return 2 * MAX_VOTING_POWER_TIER;
    }

    function state(uint256 proposalId)
        public
        view
        override(Governor)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    /**
     * @dev See {IGovernor-castVoteWithReason}.
     * reverting to avoid passsing of duplicate tier id's in params
     */
    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) public pure override returns (uint256) {
        revert("use castVote");
    }

    /**
     * @dev See {IGovernor-castVoteWithReasonAndParams}.
     * reverting to avoid passsing of duplicate tier id's in params
     */
    function castVoteWithReasonAndParams(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        bytes memory params
    ) public pure override returns (uint256) {
        revert("use castVote");
    }

    /**
     * @dev See {IGovernor-castVoteBySig}.
     * reverting to avoid passsing of duplicate tier id's in params
     */
    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure override returns (uint256) {
        revert("use castVote");
    }


    /**
     * @dev See {IGovernor-castVoteWithReasonAndParamsBySig}.
     * reverting to avoid passsing of duplicate tier id's in params
     */
    function castVoteWithReasonAndParamsBySig(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        bytes memory params,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure override returns (uint256) {
        revert("use castVote");
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor) returns (uint256) {
        if (block.timestamp <= proposalCreationThreshold) {
            revert PROPOSAL_CREATION_THRESHOLD_NOT_REACHED_YET();
        }
        return super.propose(targets, values, calldatas, description);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
