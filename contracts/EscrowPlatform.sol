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
    address private nullAddress = 0x0000000000000000000000000000000000000000;

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
        uint256 paymentDuration; // after the conditions have been fulfilled, how long until the promoter receives all the funds (ensures that it is not taken down)
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
    uint256 public nextAgreementId = 0; // XXX: Why did Sablier start at 10 000? https://github.com/sablierhq/sablier/blob/develop/packages/protocol/contracts/Sablier.sol


    mapping(uint256 => Agreement) private agreements;                               // holds all agreements by their ids
    mapping(uint256 => mapping(address => uint256)) public fulfilled;               // timestamp for when the agreement was fulfilled
    mapping(uint256 => mapping(address => uint256)) public lastPaymentReceived;     // get promoters last stream withdrawals, XXX: change to private
    // this could also go into Agreement struct, however won't be compatible with public case then


    modifier agreementExists(uint256 agreementId) {
        require(agreements[agreementId].isAgreement, "invalid agreement id");
        _;
    }




    // ==============================================

    function isFulfilled(uint256 agreementId, address who) external view returns (bool) {
        return fulfilled[agreementId][who] > 0;
    }

    function getAgreement(uint256 agreementId) public view returns (Agreement memory) {
        return agreements[agreementId];
    }

    function outstandingPayment(uint256 agreementId, address who) public view returns (uint256 amount) {
        Agreement storage agreement = agreements[agreementId];

        uint256 delta;
        if (fulfilled[agreementId][agreement.promoter] == 0)
            delta = 0;
        else
            delta = min(block.timestamp - fulfilled[agreementId][who], agreement.paymentDuration);

        if (who == agreement.promoter) {
            amount = agreement.depositAmount * delta / agreement.paymentDuration;
            return amount;
        }

        if (who == agreement.sponsor) {
            amount = agreement.depositAmount * (agreement.paymentDuration - delta) / agreement.paymentDuration;
            return amount;
        }
    }

    // ==============================================


    function fulfillAgreement(uint256 agreementId, bytes[] memory urlProof) external {
        Agreement storage agreement = agreements[agreementId];
        require(agreement.isAgreement, "invalid agreement id");
        require(agreement.timeWindowStart <= block.timestamp && block.timestamp < agreement.timeWindowStart, "Not in valid time window");
        // TODO: verify hash matches via chainlink
        // verifyChainlink(agreementId, urlProof);
        fulfilled[agreementId][agreement.promoter] = block.timestamp;   // should anyone be able to trigger fulfill?
    }

    function contestFulfilled(uint256 agreementId) external {
        Agreement storage agreement = agreements[agreementId];
        require(agreement.isAgreement, "invalid agreement id");
        require(fulfilled[agreementId][agreement.promoter] != 0, "agreement not fulfilled");
        // TODO: call chainlink to verify if tweet has been taken down / agreement conditions are not met anymore
        // using url, this means we would need to store all urls upon a fulfilled agreement
        // verifyChainlink(agreementId, urlProof);
        fulfilled[agreementId][agreement.promoter] = 0;
    }

    function withdrawPayment(uint256 agreementId) external {
        Agreement storage agreement = agreements[agreementId];
        require(agreement.isAgreement, "invalid agreement id");
        require(msg.sender == agreement.promoter, "not the promoter");
        require(fulfilled[agreementId][msg.sender] != 0, "agreement not fulfilled");

        uint256 reward = outstandingPayment(agreementId, msg.sender);
        fulfilled[agreementId][msg.sender] = block.timestamp;

        IERC20(agreement.erc20Token).transfer(msg.sender, reward);  // safeTransfer?
    }

    function cancelAgreement(uint256 agreementId) external {
        Agreement storage agreement = agreements[agreementId];
        require(agreement.isAgreement, "invalid agreement id");
        require(msg.sender == agreement.sponsor, "not the sponsor");
        require(fulfilled[agreementId][agreement.promoter] == 0, "cannot cancel a running agreement");

        agreement.isAgreement = false;
    }

    function createAgreement(
        Platform platform,
        address promoter,
        address erc20Token,
        uint256 depositAmount,
        uint256 timeWindowStart,
        uint256 timeWindowEnd,
        uint256 paymentDuration,
        bytes32 hashDigest
    ) external payable {
        require(block.timestamp < timeWindowStart, "timeWindowStart is in the past");
        require(timeWindowStart < timeWindowEnd, "timeWindowEnd is before timeWindowStart");
        require(paymentDuration > 0, "paymentDuration must be greater 0");
        require(depositAmount > 0, "depositAmount cannot be 0");
        require(promoter != msg.sender, "promoter cannot be sender");

        bool success = IERC20(erc20Token).transferFrom(msg.sender, address(this), depositAmount);
        require(success, "ERC20 Token could not be transferred");

        agreements[nextAgreementId] = Agreement({
            platform: platform,
            isAgreement: true,
            sponsor: msg.sender,
            promoter: promoter,
            erc20Token: erc20Token,
            depositAmount: depositAmount,
            timeWindowStart: timeWindowStart,
            timeWindowEnd: timeWindowEnd,
            paymentDuration: paymentDuration,
            hashDigest: hashDigest
        });

        emit AgreementCreated(nextAgreementId, msg.sender, promoter);

        nextAgreementId++;
    }
}




// WIP ...


// contract PublicEscrow {
//     address private nullAddress = 0x0000000000000000000000000000000000000000;

//     uint256 public baseFee = 50;    // per mille; fee given to platform
//     uint256 public nextAgreementId = 0; // XXX: Why did Sablier start at 10 000? https://github.com/sablierhq/sablier/blob/develop/packages/protocol/contracts/Sablier.sol

//     enum Platform {
//         TWITTER,
//         INSTAGRAM
//     }

//     struct Agreement {
//         address sponsor;        // client / sender
//         address promoter;       // nulladdress if public ?
//         address erc20Token;     // ERC20 token address
//         uint256 depositAmount;    // amount to store in contract
//         uint256 timeWindowStart;      // verify that using timestamps is "safe" (https://eips.ethereum.org/EIPS/eip-1620)
//         uint256 timeWindowEnd;        // time-window end; after this the agreement is nullified
//         uint256 paymentDuration; // after the conditions have been fulfilled, how long until the promoter receives all the funds (ensures that it is not taken down)
//         uint256 maxRecipients;  // if public, how many promoters can maximally claim this agreement
//         uint256 share;          // per mille, share of the agreement; used for public agreementings (could probably be divided up by maxRecipients)
//         bytes32 hashDigest;
//         bool isPublic;          
//         Platform platform;      // enum Platform type
//     }

//     mapping(uint256 => Agreement) private agreements;                               // holds all agreements by their ids
//     // mapping(address => EnumerableSet.UintSet) public clientAgreements;           // get clients open agreements, XXX: change to private; redundant?
//     mapping(uint256 => mapping(address => uint256)) public lastPaymentReceived;     // get promoters last stream withdrawals, XXX: change to private
//     // mapping(uint256 => mapping(address => bool)) public fulfilled;                  // were the agreement agreement's conditions met by promoter?

//     // constructor() public {}


//     function min(uint256 a, uint256 b) internal pure returns (uint256) {
//         return a < b ? a : b;
//     }
    
//     function max(uint256 a, uint256 b) internal pure returns (uint256) {
//         return a > b ? a : b;
//     }

//     function isFulfilled(address who, uint256 agreementId) external view returns (bool) {
//         return fulfilled[agreementId][who];
//     }

//     function fulfillAgreement(uint256 agreementId, bytes[] memory urlProof) external {
//         // TODO: verify via chainlink
//         bool status = true;
//         fulfilled[agreementId][msg.sender] = status;
//     }

//     function outstandingPayment(uint256 agreementId, address who) public view returns (uint256) {
//         Agreement memory agreement = agreements[agreementId];

//         // calculate the amount the promoter still has left to withdraw
//         if (who == agreement.promoter) {

//             if (!fulfilled[agreementId][agreement.promoter])
//                 return 0;
            
//             // XXX: 
//             uint256 from = max(agreement.timeWindowStart, lastPaymentReceived[agreementId][agreement.promoter]);
//             uint256 to = agreement.timeWindowEnd;
//             uint256 amount = agreement.share * agreement.depositAmount * (block.timestamp - from) / (to - from) / 10;
//             return amount;
//         }

//         if (who == agreement.sponsor) {
//             uint256 to = max(agreement.timeWindowStart, lastPaymentReceived[agreementId][agreement.promoter]); // assumes lastpaymentReceived < agreement.timeWindowEnd
//             uint256 amount = agreement.share * agreement.depositAmount * (to - agreement.timeWindowStart) / (agreement.timeWindowEnd - from) / 10;
//             return amount;

//         }

//     }

//     function createAgreement(
//         address recipient,
//         address erc20Token,
//         uint256 depositAmount,
//         uint256 timeWindowStart,
//         uint256 timeWindowEnd,
//         uint256 paymentDuration,
//         bytes32 hashDigest,
//         Platform platform
//     ) public payable {
//         require(timeWindowStart > block.timestamp, "timeWindowStart is in the past");
//         bool success = IERC20(erc20Token).transferFrom(msg.sender, address(this), depositAmount);
//         require(success, "ERC20 Token could not be transferred");

//         Agreement memory agreement = Agreement({
//             sponsor: msg.sender,
//             promoter: recipient,
//             erc20Token: erc20Token,
//             depositAmount: depositAmount,
//             timeWindowStart: timeWindowStart,
//             timeWindowEnd: timeWindowEnd,
//             paymentDuration: paymentDuration,
//             hashDigest: hashDigest,
//             platform: platform
//         });

//         agreements[nextAgreementId] = agreement;
//         nextAgreementId++;
//     }

//     function createAgreementPersonalizedTwitter(
//         address promoter,
//         address erc20Token,
//         uint256 depositAmount,
//         uint256 timeWindowStart,
//         uint256 timeWindowEnd,
//         uint256 paymentDuration,
//         bytes32 hashDigest
//         // bytes32 tweetHash
//     ) external payable {
//         this.createAgreement(promoter, erc20Token, depositAmount, timeWindowStart, timeWindowEnd, paymentDuration, 1, 1000, hashDigest,false, Platform.TWITTER);
//     }
// }
