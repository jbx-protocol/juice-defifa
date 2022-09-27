// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../structs/DefifaScoreCard.sol";
interface IDefifaScoreCardVerifier {

    function generateRoot(DefifaScoreCard[] calldata _scorecards) external view returns(bytes32);

    function verifyScorecard(bytes32[] calldata _leaves, bytes32 _merkelRoot) external pure;
}
