// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '@jbx-protocol/juice-721-delegate/contracts/JB721TieredGovernance.sol';

import './interfaces/IDefifaDelegate.sol';

/** 
  @title
  DefifaDelegate

  @notice
  Defifa specific 721 tiered delegate.

  @dev
  Adheres to -
  IDefifaDelegate: General interface for the methods in this contract that interact with the blockchain's state according to the protocol's rules.

  @dev
  Inherits from -
  JB721TieredGovernance: A generic tiered 721 delegate.
*/
contract DefifaDelegate is IDefifaDelegate, JB721TieredGovernance {
  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//

  error GAME_ISNT_OVER_YET();
  error INVALID_REDEMPTION_WEIGHTS();
  error NOTHING_TO_CLAIM();
  error UNEXPECTED();

  //*********************************************************************//
  // --------------------------- properties ---------------------------- //
  //*********************************************************************//

  /** 
    @notice 
    The redemption weight for each tier.

    @dev
    Tiers are limited to ID 100
  */
  uint256[100] private _tierRedemptionWeights;

  //*********************************************************************//
  // -------------------- private constant properties ------------------ //
  //*********************************************************************//

  /** 
    @notice
    The funding cycle number of the end game. 
  */
  uint256 public constant END_GAME_PHASE = 4;

  //*********************************************************************//
  // --------------------- public constant properties ------------------ //
  //*********************************************************************//

  /** 
    @notice 
    The total weight that can be divided among tiers.
  */
  uint256 public constant TOTAL_REDEMPTION_WEIGHT = 1_000_000_000;

  //*********************************************************************//
  // ------------------------- external views -------------------------- //
  //*********************************************************************//

  /** 
    @notice
    The redemption weight for each tier.

    @return The array of weights, indexed by tier.
  */
  function tierRedemptionWeights() external view override returns (uint256[100] memory) {
    return _tierRedemptionWeights;
  }

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  /**
    @param _projectId The ID of the project this contract's functionality applies to.
    @param _directory The directory of terminals and controllers for projects.
    @param _name The name of the token.
    @param _symbol The symbol that the token should be represented by.
    @param _fundingCycleStore A contract storing all funding cycle configurations.
    @param _baseUri A URI to use as a base for full token URIs.
    @param _tokenUriResolver A contract responsible for resolving the token URI for each token ID.
    @param _contractUri A URI where contract metadata can be found. 
    @param _pricing The pricing config of the tiers according to which token distribution will be made. Must be passed in order of contribution floor, with implied increasing value.
    @param _store A contract that stores the NFT's data.
    @param _flags A set of flags that help define how this contract works.
  */
  constructor(
    uint256 _projectId,
    IJBDirectory _directory,
    string memory _name,
    string memory _symbol,
    IJBFundingCycleStore _fundingCycleStore,
    string memory _baseUri,
    IJBTokenUriResolver _tokenUriResolver,
    string memory _contractUri,
    JB721PricingParams memory _pricing,
    IJBTiered721DelegateStore _store,
    JBTiered721Flags memory _flags
  ) {
    // Disable the safety check to not allow initializing the original contract
    codeOrigin = address(0);

    super.initialize(
      _projectId,
      _directory,
      _name,
      _symbol,
      _fundingCycleStore,
      _baseUri,
      _tokenUriResolver,
      _contractUri,
      _pricing,
      _store,
      _flags
    );
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /** 
    @notice
    Stores the redemption weights that should be used in the end game phase.

    @dev
    Only the contract's owner can set tier redemption weights.

    @param _tierWeights The tier weights to set.
  */
  function setTierRedemptionWeights(DefifaTierRedemptionWeight[] memory _tierWeights)
    external
    override
    onlyOwner
  {
    // Get a reference to the current funding cycle.
    JBFundingCycle memory _currentFundingCycle = fundingCycleStore.currentOf(projectId);

    // Make sure the game has ended.
    if (_currentFundingCycle.number < END_GAME_PHASE) revert GAME_ISNT_OVER_YET();

    // Delete the currently set redemption weights.
    delete _tierRedemptionWeights;

    // Keep a reference to the cumulative amounts.
    uint256 _cumulativeRedemptionWeight;

    // Keep a reference to the number of tier weights.
    uint256 _numberOfTierWeights = _tierWeights.length;

    for (uint256 _i; _i < _numberOfTierWeights; ) {
      // Save the tier weight. Tier's are 1 indexed and should be stored 0 indexed.
      _tierRedemptionWeights[_tierWeights[_i].id - 1] = _tierWeights[_i].redemptionWeight;

      // Increment the cumulative amount.
      _cumulativeRedemptionWeight += _tierWeights[_i].redemptionWeight;

      unchecked {
        ++_i;
      }
    }

    // Make sure the cumulative amount is contained within the total redemption weight.
    if (_cumulativeRedemptionWeight > TOTAL_REDEMPTION_WEIGHT) revert INVALID_REDEMPTION_WEIGHTS();
  }

  //*********************************************************************//
  // ------------------------ internal functions ----------------------- //
  //*********************************************************************//

  /** 
    @notice
    The cumulative weight the given token IDs have in redemptions compared to the `_totalRedemptionWeight`. 

    @param _tokenIds The IDs of the tokens to get the cumulative redemption weight of.
    @param _data The Juicebox standard project redemption data.

    @return cumulativeWeight The weight.
  */
  function _redemptionWeightOf(uint256[] memory _tokenIds, JBRedeemParamsData calldata _data)
    internal
    view
    virtual
    override
    returns (uint256 cumulativeWeight)
  {
    // Get a reference to the current funding cycle.
    JBFundingCycle memory _currentFundingCycle = fundingCycleStore.currentOf(_data.projectId);

    if (_currentFundingCycle.number < END_GAME_PHASE)
      // Otherwise return the superclass's method.
      return super._redemptionWeightOf(_tokenIds, _data);

    // If the game is over, set the weight based on the scorecard results.
    // Keep a reference to the number of tokens being redeemed.
    uint256 _tokenCount = _tokenIds.length;

    for (uint256 _i; _i < _tokenCount; ) {
      // Keep a reference to the token's tier ID.
      uint256 _tierId = store.tierIdOfToken(_tokenIds[_i]);

      // Keep a reference to the tier.
      JB721Tier memory _tier = store.tier(address(this), _tierId);

      // Calculate what percentage of the tier redemption amount a single token counts for.
      cumulativeWeight +=
        // Tier's are 1 indexed and are stored 0 indexed.
        _tierRedemptionWeights[_tierId - 1] /
        (_tier.initialQuantity - _tier.remainingQuantity);

      unchecked {
        ++_i;
      }
    }

    // If there's nothing to claim, revert to prevent burning for nothing.
    if (cumulativeWeight == 0) revert NOTHING_TO_CLAIM();
  }

  /** 
    @notice
    The cumulative weight that all token IDs have in redemptions. 

    @param _data The Juicebox standard project redemption data.

    @return The total weight.
  */
  function _totalRedemptionWeight(JBRedeemParamsData calldata _data)
    internal
    view
    virtual
    override
    returns (uint256)
  {
    // Get a reference to the current funding cycle.
    JBFundingCycle memory _currentFundingCycle = fundingCycleStore.currentOf(_data.projectId);

    // If the game is not over, use the superclass's method.
    if (_currentFundingCycle.number < END_GAME_PHASE) return super._totalRedemptionWeight(_data);

    // Otherwise, set the total weight as the total scorecard weight.
    return TOTAL_REDEMPTION_WEIGHT;
  }
}
