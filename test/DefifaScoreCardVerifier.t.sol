// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "murky/Merkle.sol";
import "../src/DefifaScoreCardVerifier.sol";
import "../src/structs/DefifaScoreCard.sol";

contract DefifaScoreCardVerifierTest is Test, Merkle {
    DefifaScoreCardVerifier public verifier;

    function setUp() public {
       verifier = new DefifaScoreCardVerifier();
    }

    function testMerkelRootGenrationWithInvalidScorecard() public {
        DefifaScoreCard[] memory scorecards = new DefifaScoreCard[](2);
        scorecards[0] = DefifaScoreCard({ tierID: 1, redemptionPercent: 600_000 });
        scorecards[1] = DefifaScoreCard({ tierID: 2, redemptionPercent: 600_000 });
        vm.expectRevert(abi.encodeWithSignature('INVALID_SCORECARD()'));
        verifier.generateRoot(scorecards);
    }

    function testMerkelRootGenrationWithValidScorecard() public {
        DefifaScoreCard[] memory scorecards = new DefifaScoreCard[](2);
        scorecards[0] = DefifaScoreCard({ tierID: 1, redemptionPercent: 600_000 });
        scorecards[1] = DefifaScoreCard({ tierID: 2, redemptionPercent: 400_000 });
        verifier.generateRoot(scorecards);
    }

    function testMerkelRootValidationWithInvalidScorecard() public {
        DefifaScoreCard[] memory scorecards = new DefifaScoreCard[](2);
        scorecards[0] = DefifaScoreCard({ tierID: 1, redemptionPercent: 600_000 });
        scorecards[1] = DefifaScoreCard({ tierID: 2, redemptionPercent: 400_000 });
        bytes32 root = verifier.generateRoot(scorecards);

        // pass in inccorrect leaves for verification
        scorecards[0] = DefifaScoreCard({ tierID: 2, redemptionPercent: 600_000 });
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encodePacked(scorecards[0].tierID, scorecards[0].redemptionPercent)); 
        leaves[1] = keccak256(abi.encodePacked(scorecards[1].tierID, scorecards[1].redemptionPercent)); 
        vm.expectRevert(abi.encodeWithSignature('INVALID_SCORECARD()'));
        verifier.verifyScorecard(leaves, root);
    }

    function testMerkelRootValidationWithValidScorecard() public {
        DefifaScoreCard[] memory scorecards = new DefifaScoreCard[](2);
        scorecards[0] = DefifaScoreCard({ tierID: 1, redemptionPercent: 600_000 });
        scorecards[1] = DefifaScoreCard({ tierID: 4, redemptionPercent: 400_000 });
        bytes32 root = verifier.generateRoot(scorecards);
        
        // generating leaves andd verifying
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encodePacked(scorecards[0].tierID, scorecards[0].redemptionPercent)); 
        leaves[1] = keccak256(abi.encodePacked(scorecards[1].tierID, scorecards[1].redemptionPercent)); 
        verifier.verifyScorecard(leaves, root);
    }

}
