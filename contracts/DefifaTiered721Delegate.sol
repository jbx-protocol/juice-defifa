// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '@jbx-protocol/juice-721-delegate/contracts/JBTiered721Delegate.sol';

import './interfaces/IDefifaTiered721Delegate.sol';

contract DefifaTiered721Delegate is IDefifaTiered721Delegate, JBTiered721Delegate {
  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//

  error INVALID_REDEMPTION_WEIGHTS();
  error UNEXPECTED();

  //*********************************************************************//
  // --------------------------- properties ---------------------------- //
  //*********************************************************************//

  // The total weight that can be divided among tiers
  uint256 public constant TOTAL_REDEMPTION_WEIGHT = 1_000_000_000;

  // Tiers are limited to ID 100
  uint256[100] public _tierRedemptionWeights;

  function tierRedemptionWeights() external override returns (uint256[100] memory) {
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
    @param _tiers The tiers according to which token distribution will be made. Must be passed in order of contribution floor, with implied increasing value.
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
    JB721TierParams[] memory _tiers,
    IJBTiered721DelegateStore _store,
    JBTiered721Flags memory _flags // TODO: call initialize in accordance to latest nft rewards version // JBTiered721Delegate( //     _projectId, //     _directory, //     _name, //     _symbol, //     _fundingCycleStore, //     _baseUri, //     _tokenUriResolver, //     _contractUri, //     _tiers, //     _store, //     _flags // )
  ) {}

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  function setTierRedemptionWeights(DefifaTierRedemptionWeight[] memory _tierWeights)
    external
    override
    onlyOwner
  {
    delete _tierRedemptionWeights;

    uint256 _cumulativeRedemptionWeight;
    for (uint256 _i; _i < _tierWeights.length; ) {
      _tierRedemptionWeights[_tierWeights[_i].id] = _tierWeights[_i].redemptionWeight;
      _cumulativeRedemptionWeight += _tierWeights[_i].redemptionWeight;

      unchecked {
        ++_i;
      }
    }

    if (_cumulativeRedemptionWeight > TOTAL_REDEMPTION_WEIGHT) revert INVALID_REDEMPTION_WEIGHTS();
  }

  /**
        @notice 
        Part of IJBFundingCycleDataSource, this function gets called when a project's token holders redeem.

        @param _data The Juicebox standard project redemption data.

        @return reclaimAmount The amount that should be reclaimed from the treasury.
        @return memo The memo that should be forwarded to the event.
        @return delegateAllocations The amount to send to delegates instead of adding to the beneficiary.
    */
  function redeemParams(JBRedeemParamsData calldata _data)
    external
    view
    override
    returns (
      uint256 reclaimAmount,
      string memory memo,
      JBRedemptionDelegateAllocation[] memory delegateAllocations
    )
  {
    // Set the only delegate allocation to be a callback to this contract.
    delegateAllocations = new JBRedemptionDelegateAllocation[](1);
    delegateAllocations[0] = JBRedemptionDelegateAllocation(this, 0);

    // Make sure fungible project tokens aren't being redeemed too.
    if (_data.tokenCount > 0) revert UNEXPECTED();

    // If redemption rate is 0, nothing can be reclaimed from the treasury
    if (_data.redemptionRate == 0) return (0, _data.memo, delegateAllocations);

    // Decode the metadata
    uint256[] memory _ids = abi.decode(_data.metadata, (uint256[]));

    // If redemption is max the reclaim Amount is the same as it cost to mint
    if (_data.redemptionRate == JBConstants.MAX_REDEMPTION_RATE) {
      for (uint256 _i; _i < _ids.length; ) {
        unchecked {
          reclaimAmount += store.tierOfTokenId(address(this), _ids[_i]).contributionFloor;

          _i++;
        }
      }

      return (reclaimAmount, _data.memo, delegateAllocations);
    }

    // Return the weighted overflow, and this contract as the delegate so that tokens can be deleted.
    return (
      PRBMath.mulDiv(_data.overflow, _redemptionWeightOf(_ids), _totalRedemptionWeight()),
      _data.memo,
      delegateAllocations
    );
  }

  //*********************************************************************//
  // ------------------------ internal functions ----------------------- //
  //*********************************************************************//

  /** 
    @notice
    The cumulative weight the given token IDs have in redemptions compared to the `_totalRedemptionWeight`. 

    @param _tokenIds The IDs of the tokens to get the cumulative redemption weight of.

    @return cumulativeWeight The weight.
  */
  function _redemptionWeightOf(uint256[] memory _tokenIds)
    internal
    view
    virtual
    override
    returns (uint256 cumulativeWeight)
  {
    uint256 _tokenCount = _tokenIds.length;

    for (uint256 _i; _i < _tokenCount; ) {
      uint256 _tierId = store.tierIdOfToken(_tokenIds[_i]);
      JB721Tier memory _tier = store.tier(address(this), _tierId);

      // Calculate what percentage of the tier redemption amount a single token counts
      cumulativeWeight +=
        _tierRedemptionWeights[_tierId] /
        (_tier.initialQuantity - _tier.remainingQuantity);

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice
    The cumulative weight that all token IDs have in redemptions. 

    @return The total weight.
  */
  function _totalRedemptionWeight() internal view virtual override returns (uint256) {
    return TOTAL_REDEMPTION_WEIGHT;
  }
}
