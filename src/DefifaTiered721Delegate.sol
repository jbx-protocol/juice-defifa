// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@jbx-protocol/juice-nft-rewards/contracts/JBTiered721Delegate.sol";

import "./structs/DefifaTierRedemptionWeight.sol";

contract DefifaTiered721Delegate is JBTiered721Delegate {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error INVALID_REDEMPTION_WEIGHTS();

    //*********************************************************************//
    // --------------------------- properties ---------------------------- //
    //*********************************************************************//

    // The total weight that can be divided among tiers
    uint256 constant TOTAL_REDEMPTION_WEIGHT = 1_000_000_000;

    // Tiers are limited to ID 100
    uint256[100] public tierRedemptionWeights;

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
        JBTiered721Flags memory _flags
    )
        JBTiered721Delegate(
            _projectId,
            _directory,
            _name,
            _symbol,
            _fundingCycleStore,
            _baseUri,
            _tokenUriResolver,
            _contractUri,
            _tiers,
            _store,
            _flags
        )
    {}

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    function setTierRedemptionWeights(
        DefifaTierRedemptionWeight[] memory _tierWeights
    ) external onlyOwner {
        delete tierRedemptionWeights;

        uint256 _cumulativeRedemptionWeight;
        for (uint256 _i; _i < _tierWeights.length; ) {
            tierRedemptionWeights[_tierWeights[_i].id] = _tierWeights[_i].redemptionWeight;
            _cumulativeRedemptionWeight += _tierWeights[_i].redemptionWeight;

            unchecked {
                ++_i;
            }
        }

        if (_cumulativeRedemptionWeight > TOTAL_REDEMPTION_WEIGHT)
            revert INVALID_REDEMPTION_WEIGHTS();
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
                tierRedemptionWeights[_tierId] /
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
    function _totalRedemptionWeight()
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return TOTAL_REDEMPTION_WEIGHT;
    }
}