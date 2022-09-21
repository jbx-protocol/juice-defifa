pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/IDefifaScoreCardVerifier.sol";


/**
Custom Errors
*/
error INVALID_SCORECARD();

contract DefifaScoreCardVerifier is IDefifaScoreCardVerifier {
    uint256 MAX_TOTAL_REDEMPTION_PERCENT = 10**6;

    function validate(ScoreCard[] memory scorecards, bytes32 _merkleRoot) external view override {   
        uint256 totalRedemptionPercent;
        // Verify the merkle proof.
        for (uint256 i = 0; i < scorecards.length; ) {
            bytes32 node = keccak256(
                abi.encodePacked(
                    scorecards[i].index,
                    scorecards[i].tierID,
                    scorecards[i].redemptionPercent
                )
            );
            if (!MerkleProof.verify(scorecards[i].merkleProof, _merkleRoot, node))
              revert INVALID_SCORECARD();
            totalRedemptionPercent += scorecards[i].redemptionPercent;
            unchecked {
                ++ i;
            }
        }
        if (totalRedemptionPercent > MAX_TOTAL_REDEMPTION_PERCENT)
          revert INVALID_SCORECARD();  
    }
}
