// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IDefifaScoreCardVerifier {
    /**
    @param index leaf index of the tier id.
    @param tierID tier id.
    @param redemptionPercent % of the redemption amount.
    @param merkleProof merkel proof for the tier id.
    */
    struct ScoreCard {
        uint256 index;
        uint256 tierID;
        uint256 redemptionPercent;
        bytes32[] merkleProof;
    }

    function validate(ScoreCard[] memory scorecards, bytes32 _merkleRoot) external view;
}
