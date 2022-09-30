// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "murky/Merkle.sol";
import "../src/DefifaScoreCardVerifier.sol";
import "../src/structs/DefifaTierRedemptionWeight.sol";

contract DefifaScoreCardVerifierTest is Test, Merkle {
    DefifaScoreCardVerifier public verifier;

    function setUp() public {
        verifier = new DefifaScoreCardVerifier();
    }

    function testMerkelRootGenrationWithInvalidScorecard() public {
        DefifaTierRedemptionWeight[] memory scorecards = new DefifaTierRedemptionWeight[](2);
        scorecards[0] = DefifaTierRedemptionWeight({
            id: 1,
            redemptionWeight: 600_000
        });
        scorecards[1] = DefifaTierRedemptionWeight({
            id: 2,
            redemptionWeight: 600_000
        });
        vm.expectRevert(abi.encodeWithSignature("INVALID_SCORECARD()"));
        verifier.generateRoot(scorecards);
    }

    function testMerkelRootGenrationWithValidScorecard() public {
        DefifaTierRedemptionWeight[] memory scorecards = new DefifaTierRedemptionWeight[](2);
        scorecards[0] = DefifaTierRedemptionWeight({
            id: 1,
            redemptionWeight: 600_000
        });
        scorecards[1] = DefifaTierRedemptionWeight({
            id: 2,
            redemptionWeight: 400_000
        });
        verifier.generateRoot(scorecards);
    }

    function testMerkelRootValidationWithInvalidScorecard() public {
        DefifaTierRedemptionWeight[] memory scorecards = new DefifaTierRedemptionWeight[](2);
        scorecards[0] = DefifaTierRedemptionWeight({
            id: 1,
            redemptionWeight: 600_000
        });
        scorecards[1] = DefifaTierRedemptionWeight({
            id: 2,
            redemptionWeight: 400_000
        });
        bytes32 root = verifier.generateRoot(scorecards);

        // pass in inccorrect leaves for verification
        scorecards[0] = DefifaTierRedemptionWeight({
            id: 2,
            redemptionWeight: 600_000
        });
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(
            abi.encodePacked(
                scorecards[0].id,
                scorecards[0].redemptionWeight
            )
        );
        leaves[1] = keccak256(
            abi.encodePacked(
                scorecards[1].id,
                scorecards[1].redemptionWeight
            )
        );
        vm.expectRevert(abi.encodeWithSignature("INVALID_SCORECARD()"));
        verifier.verifyScorecard(leaves, root);
    }

    function testMerkelRootValidationWithValidScorecard() public {
        DefifaTierRedemptionWeight[] memory scorecards = new DefifaTierRedemptionWeight[](2);
        scorecards[0] = DefifaTierRedemptionWeight({
            id: 1,
            redemptionWeight: 600_000
        });
        scorecards[1] = DefifaTierRedemptionWeight({
            id: 4,
            redemptionWeight: 400_000
        });
        bytes32 root = verifier.generateRoot(scorecards);

        // generating leaves and verifying
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(
            abi.encodePacked(
                scorecards[0].id,
                scorecards[0].redemptionWeight
            )
        );
        leaves[1] = keccak256(
            abi.encodePacked(
                scorecards[1].id,
                scorecards[1].redemptionWeight
            )
        );
        verifier.verifyScorecard(leaves, root);
    }

    function testFuzzMerkelRootGeneration(
        DefifaTierRedemptionWeight[] calldata _scorecards
    ) public {
        // root cannot be generated for a single leaf
        vm.assume(_scorecards.length > 1);
        // assuming at max we would have at most 20 entries in the scorecard
        vm.assume(_scorecards.length <= 20);
        for (uint256 i = 0; i < _scorecards.length; ) {
            // assuming max. scorecard entires as 20 hence making sure we don't have reverts since already tested the reverts above
            vm.assume(_scorecards[i].redemptionWeight <= 50_000);
            unchecked {
                ++i;
            }
        }
        verifier.generateRoot(_scorecards);
    }

    function testFuzzMerkelRootVerification(
        DefifaTierRedemptionWeight[] calldata _scorecards
    ) public {
        // root cannot be generated for a single leaf
        vm.assume(_scorecards.length > 1);
        // assuming at max we would have at most 20 entries in the scorecard
        vm.assume(_scorecards.length <= 20);
        for (uint256 i = 0; i < _scorecards.length; ) {
            // assuming max. scorecard entires as 20 hence making sure we don't have reverts since already tested the reverts above
            vm.assume(_scorecards[i].redemptionWeight <= 50_000);
            unchecked {
                ++i;
            }
        }
        bytes32 root = verifier.generateRoot(_scorecards);

        // generating leaves and verifying
        bytes32[] memory leaves = new bytes32[](_scorecards.length);
        for (uint256 i = 0; i < _scorecards.length; ) {
            leaves[i] = keccak256(
                abi.encodePacked(
                    _scorecards[i].id,
                    _scorecards[i].redemptionWeight
                )
            );
            unchecked {
                ++i;
            }
        }
        verifier.verifyScorecard(leaves, root);
    }
}
