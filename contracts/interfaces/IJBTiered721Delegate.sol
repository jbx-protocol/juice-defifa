// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

// I did this a lil hacky so I didn't get stuck in dependency hell

interface IJBTiered721Delegate {

  // function store() external view returns (IJBTiered721DelegateStore);

  function contributionToken() external view returns (address);

  function contractURI() external view returns (string memory);

  function firstOwnerOf(uint256 _tokenId) external view returns (address);

  function getTierDelegate(address _account, uint256 _tier) external view returns (address);

  function getTierVotes(address _account, uint256 _tier) external view returns (uint256);

  function getPastTierVotes(
    address _account,
    uint256 _tier,
    uint256 _blockNumber
  ) external view returns (uint256);

  function getTierTotalVotes(uint256 _tier) external view returns (uint256);

  function getPastTierTotalVotes(uint256 _tier, uint256 _blockNumber)
    external
    view
    returns (uint256);

  function adjustTiers(JB721TierParams[] memory _tierDataToAdd, uint256[] memory _tierIdsToRemove)
    external;

  function setTierDelegate(address _delegatee, uint256 _tierId) external;

  function mintReservesFor(uint256 _tierId, uint256 _count) external;

  function setDefaultReservedTokenBeneficiary(address _beneficiary) external;
}


/**
  @member contributionFloor The minimum contribution to qualify for this tier.
  @member lockedUntil The time up to which this tier cannot be removed or paused.
  @member initialQuantity The initial `remainingAllowance` value when the tier was set.
  @member votingUnits The amount of voting significance to give this tier compared to others.
  @memver reservedRate The number of minted tokens needed in the tier to allow for minting another reserved token.
  @member reservedRateBeneficiary The beneificary of the reserved tokens for this tier.
  @member encodedIPFSUri The URI to use for each token within the tier.
  @member shouldUseBeneficiaryAsDefault A flag indicating if the `reservedTokenBeneficiary` should be stored as the default beneficiary for all tiers.
*/
struct JB721TierParams {
  uint256 contributionFloor;
  uint256 lockedUntil;
  uint256 initialQuantity;
  uint256 votingUnits;
  uint256 reservedRate;
  address reservedTokenBeneficiary;
  bytes32 encodedIPFSUri;
  bool shouldUseBeneficiaryAsDefault;
}
