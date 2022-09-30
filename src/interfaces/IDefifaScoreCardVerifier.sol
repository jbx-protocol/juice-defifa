// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../structs/DefifaTierRedemptionWeight.sol";
interface IDefifaScoreCardVerifier {

    function generateRoot(DefifaTierRedemptionWeight[] calldata _scorecards) external returns(bytes32);

    function verifyScorecard(bytes32[] calldata _leaves, bytes32 _merkelRoot) external view;
}
