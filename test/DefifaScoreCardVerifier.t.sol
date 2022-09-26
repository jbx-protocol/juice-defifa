// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.15;

// import "forge-std/Test.sol";
// import "../src/DefifaScoreCardVerifier.sol";
// import "../src/structs/DefifaScoreCard.sol";

// contract DefifaScoreCardVerifierTest is Test, DefifaScoreCard {
//     DefifaScoreCardVerifier public verifier;

//     function setUp() public {
//        verifier = new DefifaScoreCardVerifier();
//     }

//     function testMerkelRootGenrationWithInvalidScorecard() public {
//         ScoreCard[] memory scorecards = new ScoreCard[](2);
//         scorecards[0] = ScoreCard({ tierID: 1, redemptionPercent: 600_000 });
//         scorecards[1] = ScoreCard({ tierID: 2, redemptionPercent: 600_000 });
//         vm.expectRevert(abi.encodeWithSignature('INVALID_SCORECARD()'));
//         verifier.generateRoot(scorecards);
//     }

//     function testMerkelRootGenrationWithValidScorecard() public {
//         ScoreCard[] memory scorecards = new ScoreCard[](2);
//         scorecards[0] = ScoreCard({ tierID: 1, redemptionPercent: 600_000 });
//         scorecards[1] = ScoreCard({ tierID: 2, redemptionPercent: 400_000 });
//         verifier.generateRoot(scorecards);
//     }

//     function testMerkelRootValidationWithInvalidScorecard() public {
//         ScoreCard[] memory scorecards = new ScoreCard[](2);
//         scorecards[0] = ScoreCard({ tierID: 1, redemptionPercent: 600_000 });
//         scorecards[1] = ScoreCard({ tierID: 2, redemptionPercent: 400_000 });
//         bytes32 root = verifier.generateRoot(scorecards);
//         // pass in inccorrect scorecard for verification
//         scorecards[0] = ScoreCard({ tierID: 2, redemptionPercent: 600_000 });
//         vm.expectRevert(abi.encodeWithSignature('INVALID_SCORECARD()'));
//         verifier.verifyScorecard(scorecards, root);
//     }

//     function testMerkelRootValidationWithValidScorecard() public {
//         ScoreCard[] memory scorecards = new ScoreCard[](2);
//         scorecards[0] = ScoreCard({ tierID: 1, redemptionPercent: 600_000 });
//         scorecards[1] = ScoreCard({ tierID: 4, redemptionPercent: 400_000 });
//         bytes32 root = verifier.generateRoot(scorecards);
//         verifier.verifyScorecard(scorecards, root);
//     }

// }
