pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "murky/Merkle.sol";
import "./interfaces/IDefifaScoreCardVerifier.sol";


/**
Custom Errors
*/
error INVALID_SCORECARD();

contract DefifaScoreCardVerifier is IDefifaScoreCardVerifier, Merkle {
    // for handling precision
    uint256 MAX_TOTAL_REDEMPTION_PERCENT = 10**6;
    
    /**
    @notice Generates scorecard based on the raw scorecard data passed.
    @param _scorecards array of the scorcard struct.
    */
    function generateRoot(ScoreCard[] memory _scorecards) external view override returns(bytes32) {   
        uint256 totalRedemptionPercent;
        bytes32[] memory data = new bytes32[](_scorecards.length);
        // Verify the merkle proof.
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
}
