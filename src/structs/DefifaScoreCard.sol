// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/**
    @param tierID tier id.
    @param redemptionPercent % of the redemption amount.
*/
struct DefifaScoreCard {
    uint128 tierID;
    uint128 redemptionPercent;
}
