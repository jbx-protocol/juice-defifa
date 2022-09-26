pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "murky/Merkle.sol";
import "./interfaces/IDefifaScoreCardVerifier.sol";


/**
Custom Errors
*/
error INVALID_SCORECARD();

//TODO: We should transfer the ownership of the verifier to the governer
contract DefifaScoreCardVerifier is IDefifaScoreCardVerifier, Merkle {
    // for handling precision
    uint256 MAX_TOTAL_REDEMPTION_PERCENT = 10**6;
    
    /**
    @notice Generates merkel root based on the raw scorecard data passed.
    @param _scorecards array of the scorcard struct.
    */
    function generateRoot(ScoreCard[] memory _scorecards) external view override returns(bytes32) {   
        uint256 totalRedemptionPercent;
        bytes32[] memory data = new bytes32[](_scorecards.length);
        // generate the merkle proof.
        for (uint256 i = 0; i < _scorecards.length; ) {
            data[i] = keccak256(abi.encodePacked(_scorecards[i].tierID, _scorecards[i].redemptionPercent));
            totalRedemptionPercent += _scorecards[i].redemptionPercent;
            unchecked {
                ++ i;
            }
        }
        if (totalRedemptionPercent > MAX_TOTAL_REDEMPTION_PERCENT)
          revert INVALID_SCORECARD();  
        return getRoot(data);
    }

    
    /**
    @notice Verifies scorecard after quorum is reached or game end time reaches.
    @param _leaves leaves of the root.
    @param _merkelRoot merkel root to verify.
    */
    function verifyScorecard(bytes32[] memory _leaves, bytes32 _merkelRoot) external pure override {         
        for (uint256 j = 0; j < _leaves.length; ) {
            bytes32[] memory proof = getProof(_leaves, j);
            bool verified = verifyProof(_merkelRoot, proof, _leaves[j]);
            if (!verified)
              revert INVALID_SCORECARD();
            unchecked {
                ++ j;
            }
        }
    }
}
