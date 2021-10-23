//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract Escrow is ChainlinkClinet, Ownable, Pausable {

contract Escrow {
    address private nullAddress = 0x0000000000000000000000000000000000000000;

    uint256 public baseFee = 50;    // per mille; fee given to platform
    uint256 public nextAgreementId = 0; // XXX: Why did Sablier start at 10 000? https://github.com/sablierhq/sablier/blob/develop/packages/protocol/contracts/Sablier.sol

    enum Platform {
        TWITTER,
        INSTAGRAM
    }

    struct Agreement {
        address sponsor;        // client / sender
        address promoter;       // nulladdress if public ?
        address erc20Token;     // ERC20 token address
        uint256 tokenAmount;    // amount to store in contract
        uint256 startTime;      // verify that using timestamps is "safe" (https://eips.ethereum.org/EIPS/eip-1620)
        uint256 endTime;        // time-window end; after this the agreement is nullified
        uint256 paymentDuration; // after the conditions have been fulfilled, how long until the promoter receives all the funds (ensures that it is not taken down)
        uint256 maxRecipients;  // if public, how many promoters can maximally claim this agreement
        uint256 share;          // per mille, share of the agreement; used for public agreementings (could probably be divided up by maxRecipients)
        uint256 hashDigest;
        bool isPublic;          
        Platform platform;      // enum Platform type
    }

    mapping(uint256 => Agreement) private agreements;                               // holds all agreements by their ids
    // mapping(address => EnumerableSet.UintSet) public clientAgreements;           // get clients open agreements, XXX: change to private; redundant?
    mapping(uint256 => mapping(address => uint256)) public lastPaymentReceived;     // get promoters last stream withdrawals, XXX: change to private
    mapping(uint256 => mapping(address => bool)) public fulfilled;                  // were the agreement agreement's conditions met by promoter?

    // constructor() public {}


    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function getFulfilledStatus(address promoter, uint256 agreementId, bytes[] memory urlProof) external view returns (bool) {
        return fulfilled[agreementId][msg.sender];
    }

    function fulfillAgreement(address promoter, uint256 agreementId, bytes[] memory urlProof) external {
        // TODO: verify via chainlink
        bool status = true;
        fulfilled[agreementId][msg.sender] = status;
    }

    function calculatePayment(uint256 agreementId, address who) public view returns (uint256) {
        Agreement memory agreement = agreements[agreementId];
        if (who == agreement.promoter) {

            if (!fulfilled[agreementId][agreement.promoter])
                return 0;
            
            uint256 from = max(agreement.startTime, lastPaymentReceived[agreementId][agreement.promoter]);
            uint256 to = agreement.endTime;
            uint256 delta = to - from;

        }

        if (who == agreement.sponsor) {

        }

    }

    function createAgreement(
        address _recipient,
        address _erc20Token,
        uint256 _tokenAmount,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _paymentDuration,
        uint256 _maxRecipients,
        uint256 _share,
        bool _isPublic,
        Platform _platform
    ) external payable {
        require(_startTime > block.timestamp, "startTime is in the past");
        bool success = IERC20(_erc20Token).transferFrom(msg.sender, address(this), _tokenAmount);
        require(success, "ERC20 Token could not be transferred");

        Agreement memory agreement = Agreement({
            sponsor: msg.sender,
            promoter: _recipient,
            erc20Token: _erc20Token,
            tokenAmount: _tokenAmount,
            startTime: _startTime,
            endTime: _endTime,
            paymentDuration: _paymentDuration,
            maxRecipients: _maxRecipients,
            share: _share,
            isPublic: _isPublic,
            platform: _platform
        });

        agreements[nextAgreementId] = agreement;
        nextAgreementId++;
    }

    function createAgreementPersonalizedTwitter(
        address promoter,
        address erc20Token,
        uint256 tokenAmount,
        uint256 startTime,
        uint256 endTime,
        uint256 paymentDuration
        // bytes32 tweetHash
    ) external payable {
        this.createAgreement(promoter, erc20Token, tokenAmount, startTime, endTime, paymentDuration, 1, 1000, false, Platform.TWITTER);
    }
}
