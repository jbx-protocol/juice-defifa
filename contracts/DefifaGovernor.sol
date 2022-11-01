// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '@paulrberg/contracts/math/PRBMath.sol';
import '@openzeppelin/contracts/governance/Governor.sol';
import '@openzeppelin/contracts/governance/extensions/GovernorSettings.sol';
import '@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol';
import './interfaces/IDefifaGovernor.sol';
import './DefifaDelegate.sol';

contract DefifaGovernor is Governor, GovernorCountingSimple, GovernorSettings, IDefifaGovernor {
  error INCORRECT_TIER_ORDER(uint256, uint256[]);
  error INVALID_PROPOSAL_CREATION_THRESHOLD_TIME();

  // How many seconds does 1 block take
  uint256 internal constant BLOCKTIME_SECONDS = 12;
  // The max voting power 1 tier has if everyone votes
  uint256 public constant override MAX_VOTING_POWER_TIER = 1_000_000_000;
  // The votingDelay that is set after the contract gets deployed
  uint256 public constant VOTING_DELAY = 1 days;

  // The datasource for votingpower
  DefifaDelegate public immutable defifaDelegate;

  // proposal creation threshold time
  uint256 public immutable proposalCreationThreshold;

  constructor(DefifaDelegate _defifaDelegate, uint256 _proposalCreationThreshold)
    Governor('DefifaGovernor')
    GovernorSettings(
      1, /* 1 block */
      45818, /* 1 week */
      0
    )
  {
    defifaDelegate = _defifaDelegate;
    proposalCreationThreshold = _proposalCreationThreshold;
  }

  /**
   * Helper method for 'propose' that simplifies interaction with governance for defifa
   */
  function submitScorecards(DefifaTierRedemptionWeight[] calldata _tierWeights)
    external
    override
    returns (uint256)
  {
    // Build the calldata to the delegate
    (
      address[] memory _targets,
      uint256[] memory _values,
      bytes[] memory _calldatas
    ) = _buildScorecardCalldata(_tierWeights);

    // Propose it.
    return propose(_targets, _values, _calldatas, '');
  }

  /**
   * Helper method for 'execute' that simplifies interaction with governance for defifa
   */
  function ratifyScorecard(DefifaTierRedemptionWeight[] calldata _tierWeights)
    external
    override
    returns (uint256)
  {
    // Build the calldata to the delegate
    (
      address[] memory _targets,
      uint256[] memory _values,
      bytes[] memory _calldatas
    ) = _buildScorecardCalldata(_tierWeights);

    // Attempt to execute it
    return execute(_targets, _values, _calldatas, keccak256(''));
  }

  function _buildScorecardCalldata(DefifaTierRedemptionWeight[] calldata _tierWeights)
    internal
    view
    returns (
      address[] memory,
      uint256[] memory,
      bytes[] memory
    )
  {
    // Build the calldata for the call to the delegate
    bytes memory _calldata = abi.encodeWithSelector(
      DefifaDelegate.setTierRedemptionWeights.selector,
      (_tierWeights)
    );

    // Set the target to the delegate
    address[] memory _targets = new address[](1);
    _targets[0] = address(defifaDelegate);

    // This call requires no value
    uint256[] memory _values = new uint256[](1);

    // Add the delegate call
    bytes[] memory _calldatas = new bytes[](1);
    _calldatas[0] = _calldata;

    return (_targets, _values, _calldatas);
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
    uint256[] memory _tiers = abi.decode(params, (uint256[]));
    uint256 _numbeOfTiers = _tiers.length;

    // Loop over all tiers gathering the voting share of the user
    uint256 _prevTier;
    for (uint256 _i; _i < _numbeOfTiers; ) {
      // Enforce the tiers to be in ascending order, reverts if
      // there are any duplicates or the tiers are incorrecly sorted
      if (_tiers[_i] <= _prevTier) revert INCORRECT_TIER_ORDER(_i, _tiers);
      _prevTier = _tiers[_i];

      uint256 _tierVotingPower = defifaDelegate.getPastTierVotes(account, _tiers[_i], blockNumber);

      unchecked {
        if (_tierVotingPower != 0) {
          votingPower += PRBMath.mulDiv(
            _tierVotingPower,
            MAX_VOTING_POWER_TIER,
            defifaDelegate.getPastTierTotalVotes(_tiers[_i], blockNumber)
          );
        }

        ++_i;
      }
    }
  }

  /**
   * @dev Default additional encoded parameters used by castVote methods that don't include them
   */
  function _defaultParams() internal view virtual override returns (bytes memory) {
    // TODO: should we do this on every time or should we just store this, what is cheaper...
    uint256 _count = defifaDelegate.store().maxTierIdOf(address(defifaDelegate));
    uint256[] memory _ids = new uint256[](_count);

    // Add all tiers to the array
    for (uint256 _i; _i < _count; ) {
      // Tiers start counting from 1
      _ids[_i] = _i + 1;

      unchecked {
        ++_i;
      }
    }

    return abi.encode(_ids);
  }

  // Overrides we have to do

  function votingDelay() public view override(IGovernor, GovernorSettings) returns (uint256) {
    // After the contract initially deploys there is a long delay, once this long delay has passed we use `VOTING_DELAY`
    if (proposalCreationThreshold - VOTING_DELAY > block.timestamp) {
      return (proposalCreationThreshold - block.timestamp) / BLOCKTIME_SECONDS;
    }

    return VOTING_DELAY / BLOCKTIME_SECONDS;
  }

  function votingPeriod() public view override(IGovernor, GovernorSettings) returns (uint256) {
    return super.votingPeriod();
  }

  function quorum(uint256 blockNumber) public pure override(IGovernor) returns (uint256) {
    blockNumber;
    // TODO: I just picked some random value for now, decide what a appropriate quorum should be
    return 2 * MAX_VOTING_POWER_TIER;
  }

  function state(uint256 proposalId) public view override(Governor) returns (ProposalState) {
    return super.state(proposalId);
  }

  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) public override(Governor) returns (uint256) {
    return super.propose(targets, values, calldatas, description);
  }

  function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
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

  function _executor() internal view override(Governor) returns (address) {
    return super._executor();
  }

  function supportsInterface(bytes4 interfaceId) public view override(Governor) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}
