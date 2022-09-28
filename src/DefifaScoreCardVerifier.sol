pragma solidity ^0.8.15;

import "murky/Merkle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDefifaScoreCardVerifier.sol";


/**
Custom Errors
*/
error INVALID_SCORECARD();

// Transfer ownership to governer on deploymment.
contract DefifaScoreCardVerifier is IDefifaScoreCardVerifier, Merkle, Ownable {
    // for handling precision so max is 100 %
    uint256 MAX_TOTAL_REDEMPTION_PERCENT = 10**6;
    
    /**
    @notice Generates merkel root based on the raw scorecard data passed.
    @param _scorecards array of the scorcard struct.
    */
    function generateRoot(DefifaScoreCard[] calldata _scorecards) external view override onlyOwner returns(bytes32) {   
        uint256 totalRedemptionPercent;
        // get a refrence to the scorecard array length
        uint256 scorecardLength = _scorecards.length;
        bytes32[] memory data = new bytes32[](scorecardLength);
        // generate the merkle proof.
        for (uint256 i = 0; i < scorecardLength; ) {
            data[i] = keccak256(abi.encodePacked(_scorecards[i].tierID, _scorecards[i].redemptionPercent));   
            unchecked {
                totalRedemptionPercent += _scorecards[i].redemptionPercent;
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
    function verifyScorecard(bytes32[] calldata _leaves, bytes32 _merkelRoot) external view onlyOwner override {      
        // get a refrence to the leave array length
        uint256 leavesLength = _leaves.length;   
        for (uint256 j = 0; j < leavesLength; ) {
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
