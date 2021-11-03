// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@chainlink/contracts/src/v0.8/ChainlinkClient.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import 'hardhat/console.sol';

contract APIConsumerTwitter is ChainlinkClient {
  using Chainlink for Chainlink.Request;

  bool public isSuccessful;

  address private owner;
  address private oracle;
  mapping(string => bytes32) jobIds;
  uint256 private fee;
  address private linkTokenAddress;

  function parseTweetIds(string[] memory _tweetIds) internal pure returns (string memory) {
    string memory result = '';
    for (uint256 i = 0; i < _tweetIds.length; i++) {
      result = string(abi.encodePacked(result, ',', _tweetIds[i]));
    }
    return result;
  }

  /**
   * Network: Kovan
   * Oracle: 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8 (Chainlink Devrel
   * Node)
   * Job ID: d5270d1c311941d0b08bead21fea7747
   * Fee: 0.1 LINK
   */
  constructor() {
    setPublicChainlinkToken();
    owner = msg.sender;
    oracle = 0x521E899DD6c47ea8DcA360Fc46cA41e5A904d28b;
    jobIds['Timeline'] = 'e5ce0aaf603d4aa2be36b62bb296ce96';
    jobIds['Lookup'] = '438fb98017e94736ba2329964c164a6c';
    fee = 0.1 * 10**18; // (Varies by network and job)
    linkTokenAddress = 0xa36085F69e2889c224210F603D836748e7dC0088;
  }

  /**
   * Create a Chainlink request to retrieve API response, find the target
   * data, then multiply by 1000000000000000000 (to remove decimal places from data).
   */
  function requestTwitterTimelineData(string memory _userId, string memory _tweetHash)
    external
    returns (bytes32 requestId)
  {
    Chainlink.Request memory request = buildChainlinkRequest(
      jobIds['Timeline'],
      address(this),
      this.fulfill.selector
    );

    request.add('userid', _userId);
    request.add('tweetHash', _tweetHash);
    request.add('endpoint', 'user_timeline.json');

    // Sends the request
    return sendChainlinkRequestTo(oracle, request, fee);
  }

  function requestTwitterLookupData(string[] memory _tweetIds, string memory _tweetHash)
    external
    returns (bytes32 requestId)
  {
    Chainlink.Request memory request = buildChainlinkRequest(
      jobIds['Lookup'],
      address(this),
      this.fulfill.selector
    );
    string memory _parsedTweetIds = parseTweetIds(_tweetIds);

    request.add('tweetids', _parsedTweetIds);
    request.add('tweetHash', _tweetHash);
    request.add('endpoint', 'lookup.json');

    // Sends the request
    return sendChainlinkRequestTo(oracle, request, fee);
  }

  /**
   * Receive the response in the form of uint256
   */
  function fulfill(bytes32 _requestId, bool _isSuccessful)
    public
    recordChainlinkFulfillment(_requestId)
  {
    isSuccessful = _isSuccessful;
  }

  function getIsSuccessful() external view returns (bool) {
    return isSuccessful;
  }

  function withdrawLink() external {
    require(msg.sender == owner);
    uint256 balance = IERC20(linkTokenAddress).balanceOf(address(this));
    IERC20(linkTokenAddress).transfer(msg.sender, balance);
  } //- Implement a withdraw function to avoid locking your LINK in the contract
}
