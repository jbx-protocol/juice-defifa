// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

/**
  @member id The tier's ID.
  @member redemptionWeight the weight that each token of this tier can redeem for
  packing to reduce calldata size
*/
struct DefifaTierRedemptionWeight {
  uint128 id;
  uint128 redemptionWeight;
}
