pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/IDefifaScoreCardVerifier.sol";


/**
Custom Errors
*/
error INVALID_SCORECARD();

contract DefifaScoreCardVerifier is IDefifaScoreCardVerifier {
    // for handling precision
    uint256 MAX_TOTAL_REDEMPTION_PERCENT = 10**6;
    
    /**
    @notice Validates scorecards with the merkel root passed.
    @param _scorecards array of the scorcard struct.
    @param _merkleRoot merkel root.
    */
    function validate(ScoreCard[] memory _scorecards, bytes32 _merkleRoot) external view override {   
        uint256 totalRedemptionPercent;
        // Verify the merkle proof.
        for (uint256 i = 0; i < _scorecards.length; ) {
            bytes32 node = keccak256(
                abi.encodePacked(
                    _scorecards[i].index,
                    _scorecards[i].tierID,
                    _scorecards[i].redemptionPercent
                )
            );
            if (!MerkleProof.verify(_scorecards[i].merkleProof, _merkleRoot, node))
              revert INVALID_SCORECARD();
            totalRedemptionPercent += _scorecards[i].redemptionPercent;
            unchecked {
                ++ i;
            }
        }
        if (totalRedemptionPercent > MAX_TOTAL_REDEMPTION_PERCENT)
          revert INVALID_SCORECARD();  
    }
}
