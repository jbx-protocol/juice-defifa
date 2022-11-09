// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '@jbx-protocol/juice-721-delegate/contracts/interfaces/IJB721TieredGovernance.sol';
import './../structs/DefifaTierRedemptionWeight.sol';

interface IDefifaDelegate is IJB721TieredGovernance {
  function TOTAL_REDEMPTION_WEIGHT() external returns (uint256);

  function MINT_GAME_PHASE() external returns (uint256);

  function END_GAME_PHASE() external returns (uint256);

  function tierRedemptionWeights() external returns (uint256[128] memory);

  function amountRedeemed() external returns (uint256);

  function redeemedFromTier(uint256 _tierId) external returns (uint256);

  function setTierRedemptionWeights(DefifaTierRedemptionWeight[] memory _tierWeights) external;
}
