// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "prb-math/PRBMath.sol";

import "./interfaces/IJBTiered721Delegate.sol";

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

// TODO: Set/enforce a starting time after which proposals may be accepted (prevent a propsal being made after first mint)
contract DefifaGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorTimelockControl
{

   // We need to know what range of tiers is included
    uint256 constant STARTING_ID = 0;
    uint256 constant ENDING_ID = 12;

   // The max voting power 1 tier has if everyone votes
    uint256 constant MAX_VOTING_POWER_TIER = 1_000_000_000;

   // The datasource for votingpower
    IJBTiered721Delegate jbTieredRewards;

    constructor(
        IJBTiered721Delegate _jbTieredRewards,
        TimelockController _timelock
    )
        Governor("DefifaGovernor")
        GovernorSettings(
            1, /* 1 block */
            45818, /* 1 week */
            0
        )
        GovernorTimelockControl(_timelock)
    {
        jbTieredRewards = _jbTieredRewards;
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

        // TODO: IMPORTANT! Enforce there are no duplicates in _tiers

        // Loop over all tiers gathering the voting share of the user
        for (uint256 _i; _i < _tiers_length; ) {
            unchecked {
                votingPower += PRBMath.mulDiv(
                    jbTieredRewards.getPastTierVotes(
                        account,
                        _tiers[_i],
                        blockNumber
                    ),
                    MAX_VOTING_POWER_TIER,
                    jbTieredRewards.getPastTierTotalVotes(
                        _tiers[_i],
                        blockNumber
                    )
                );

                ++_i;
            }
        }
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
       uint256 _count = ENDING_ID - STARTING_ID;
       uint256[] memory _ids = new uint256[](_count);

       for(uint256 _i; _i < _count;){
          _ids[_i] = STARTING_ID + _i;

          unchecked{ 
             ++_i;
          }
       }

        return abi.encodePacked(_ids);
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
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor, IGovernor) returns (uint256) {
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
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
