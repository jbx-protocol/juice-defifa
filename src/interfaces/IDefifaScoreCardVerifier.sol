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
        uint256 tierID;
        uint256 redemptionPercent;
    }

    function generateRoot(ScoreCard[] memory _scorecards) external view returns(bytes32);

    function verifyScorecard(ScoreCard[] memory _scorecards, bytes32 _merkelRoot) external view;
}
