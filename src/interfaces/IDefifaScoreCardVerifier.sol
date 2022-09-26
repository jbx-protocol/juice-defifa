// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../structs/DefifaScoreCard.sol";
interface IDefifaScoreCardVerifier is DefifaScoreCard {

    function generateRoot(ScoreCard[] memory _scorecards) external view returns(bytes32);

    function verifyScorecard(bytes32[] memory _leaves, bytes32 _merkelRoot) external pure;
}
