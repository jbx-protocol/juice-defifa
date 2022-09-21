// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IDefifaScoreCardVerifier {
    struct ScoreCard {
        uint256 index;
        uint256 tierID;
        uint256 redemptionPercent;
        bytes32[] merkleProof;
    }

    function validate(ScoreCard[] memory scorecards, bytes32 _merkleRoot) external view;
}
