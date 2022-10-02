pragma solidity ^0.8.15;

import "murky/Merkle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDefifaScoreCardVerifier.sol";


/**
Custom Errors
*/
error INVALID_SCORECARD();

contract DefifaScoreCardVerifier is IDefifaScoreCardVerifier, Merkle {
    // for handling precision so max is 100 %
    uint256 TOTAL_REDEMPTION_WEIGHT = 1_000_000_000;

    // EVENTS
    event RootGenerated(bytes32 root, DefifaTierRedemptionWeight[] scorecards, bytes32[] leaves);
    
    /**
    @notice Generates merkel root based on the raw scorecard data passed.
    @param _scorecards array of the scorcard struct.
    */
    function generateRoot(DefifaTierRedemptionWeight[] calldata _scorecards) external override returns(bytes32 root) {   
        uint256 totalRedemptionPercent;
        // get a refrence to the scorecard array length
        uint256 scorecardLength = _scorecards.length;
        bytes32[] memory leaves = new bytes32[](scorecardLength);
        // generate the merkle proof.
        for (uint256 i = 0; i < scorecardLength; ) {
            leaves[i] = keccak256(abi.encodePacked(_scorecards[i].id, _scorecards[i].redemptionWeight));   
            unchecked {
                totalRedemptionPercent += _scorecards[i].redemptionWeight;
                ++ i;
            }
        }
        if (totalRedemptionPercent > TOTAL_REDEMPTION_WEIGHT)
          revert INVALID_SCORECARD();

        root = getRoot(leaves);
        emit RootGenerated(root, _scorecards, leaves);
    }

    
    /**
    @notice Verifies scorecard after quorum is reached or game end time reaches.
    @param _leaves leaves of the root.
    @param _merkelRoot merkel root to verify.
    */
    function verifyScorecard(bytes32[] calldata _leaves, bytes32 _merkelRoot) external pure override {      
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
