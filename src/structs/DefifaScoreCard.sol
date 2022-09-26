// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface DefifaScoreCard {
    /**
    @param tierID tier id.
    @param redemptionPercent % of the redemption amount.
    */
    struct ScoreCard {
        uint256 tierID;
        uint256 redemptionPercent;
    }
}