//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


// contract Escrow is ChainlinkClinet, Ownable, Pausable {
//     address private nullAddress = 0x0000000000000000000000000000000000000000;

contract IEscrow {
    event AgreementCreated(
        uint256 indexed agreementId,
        address indexed sponsor,
        address indexed promoter
    );
}


contract Escrow is IEscrow {
// 
    enum Platform {
        TWITTER,
        INSTAGRAM
    }

    struct Agreement {
        Platform platform;      // enum Platform type
        bool isAgreement;       // XXX: other similar mappings(uint => struct) implement a bool check. Investigate why this should be done.. hash collisions?
        address sponsor;        // client / sender
        address promoter;       // nulladdress if public ?
        address erc20Token;     // ERC20 token address
        uint256 depositAmount;    // amount to store in contract
        uint256 timeWindowStart;      // verify that using timestamps is "safe" (https://eips.ethereum.org/EIPS/eip-1620)
        uint256 timeWindowEnd;        // time-window end; after this the agreement is nullified
        uint256 tweetMinDuration; // after the conditions have been fulfilled, how long until the promoter receives all the funds (ensures that it is not taken down)
        bytes32 hashDigest;     // hash to verify against
    }

    // XXX: should use a library for this
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}

// Design choices:
// use mapping for indexing (arrays are essentially just that, but more costly due to deletion operations etc)
// Combine private, public, personalized escrow all in one?
// pros: - simpler handling, less redundant code
//       - could mean more gas costs for write in abstracted struct, because all fields are written to
// cons: - could lead to bugs
//       - separating cases needs individual mappings / lists (-> more deploy gas costs?)

contract PrivateEscrow is Escrow {

    uint256 public baseFee = 50;    // per mille; fee given to platform
    uint256 public agreementCount = 0; // XXX: Why did Sablier start at 10 000? https://github.com/sablierhq/sablier/blob/develop/packages/protocol/contracts/Sablier.sol

    address public owner;


    mapping(uint256 => Agreement) private agreements;                               // holds all agreements by their ids
    mapping(uint256 => bool) public fulfilled;               // timestamp for when the agreement was fulfilled
    // this could also go into Agreement struct, however won't be compatible with public case then


    // modifier agreementExists(uint256 agreementId) {
    //     require(agreements[agreementId].isAgreement, "invalid agreement id");
    //     _;
    // }

    constructor () {
        owner = msg.sender;
    }



    // ==============================================
    function isFulfilled(uint256 agreementId) external view returns (bool) {
        return fulfilled[agreementId];
    }

    function getAgreement(uint256 agreementId) public view returns (Agreement memory) {
        return agreements[agreementId];
    }

    // ==============================================


    function fulfillAgreement(uint256 agreementId, bytes[] memory urlProof) external {
        Agreement storage agreement = agreements[agreementId];
        require(agreement.isAgreement, "invalid agreement id");
        require(agreement.timeWindowStart <= block.timestamp && block.timestamp < agreement.timeWindowStart, "not in valid time window");
        require(!fulfilled[agreementId], "agreement already fulfilled");
        // TODO: verify hash matches via chainlink
        // verifyChainlink(agreementId, urlProof);
        fulfilled[agreementId] = true;   // should anyone be able to trigger fulfill?

        bool success = IERC20(agreement.erc20Token).transfer(agreement.promoter, agreement.depositAmount);  // safeTransfer?
        require(success, "ERC20 Token could not be transferred");
    }

    function revokeAgreement(uint256 agreementId) external {
        Agreement storage agreement = agreements[agreementId];
        require(agreement.isAgreement, "invalid agreement id");
        require(agreement.timeWindowEnd < block.timestamp, "must be after valid time window");
        require(!fulfilled[agreementId], "agreement already fulfilled");
        // TODO: call chainlink to verify if tweet has been taken down / agreement conditions are not met anymore
        // using url, this means we would need to store all urls upon a fulfilled agreement
        // verifyChainlink(agreementId, urlProof);

        agreement.isAgreement = false;

        bool success = IERC20(agreement.erc20Token).transfer(agreement.sponsor, agreement.depositAmount);
        require(success, "ERC20 Token could not be transferred");
    }

    function createAgreement(
        Platform platform,
        address promoter,
        address erc20Token,
        uint256 depositAmount,
        uint256 timeWindowStart,
        uint256 timeWindowEnd,
        uint256 tweetMinDuration,
        bytes32 hashDigest
    ) external payable {
        require(block.timestamp < timeWindowStart, "timeWindowStart is in the past");
        require(timeWindowStart < timeWindowEnd, "timeWindowEnd is before timeWindowStart");
        require(tweetMinDuration > 0, "tweetMinDuration must be greater 0");
        require(depositAmount > 0, "depositAmount cannot be 0");
        require(promoter != msg.sender, "promoter cannot be sender");

        bool success = IERC20(erc20Token).transferFrom(msg.sender, address(this), depositAmount);
        require(success, "ERC20 Token could not be transferred");

        agreements[agreementCount] = Agreement({
            platform: platform,
            isAgreement: true,
            sponsor: msg.sender,
            promoter: promoter,
            erc20Token: erc20Token,
            depositAmount: depositAmount,
            timeWindowStart: timeWindowStart,
            timeWindowEnd: timeWindowEnd,
            tweetMinDuration: tweetMinDuration,
            hashDigest: hashDigest
        });

        emit AgreementCreated(agreementCount, msg.sender, promoter);

        agreementCount++;
    }
}