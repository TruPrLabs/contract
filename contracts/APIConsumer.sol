//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@chainlink/contracts/src/v0.8/ChainlinkClient.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import 'hardhat/console.sol';

contract APIConsumer is ChainlinkClient {
  address private owner;

  // Chainlink
  using Chainlink for Chainlink.Request;

  address private oracle = 0x521E899DD6c47ea8DcA360Fc46cA41e5A904d28b;
  address private linkToken = 0xa36085F69e2889c224210F603D836748e7dC0088;

  bytes32 private jobIdTimeline = bytes32('e5ce0aaf603d4aa2be36b62bb296ce96');
  bytes32 private jobIdLookup = bytes32('438fb98017e94736ba2329964c164a6c');

  uint256 linkTokenFee = 0.1 * 10**18;

  constructor(address _oracle, address _linkToken) {
    owner = msg.sender;
    oracle = _oracle;
    linkToken = _linkToken;
    setPublicChainlinkToken();
  }

  function verifyTimelineData(bytes memory data, bytes4 fulfillSelector)
    external
    returns (bytes32 requestId)
  {
    Chainlink.Request memory request = buildChainlinkRequest(
      jobIdTimeline,
      address(this),
      fulfillSelector
    );

    request.add('data', string(data));
    // request.add('endpoint', 'user_timeline.json');

    return sendChainlinkRequestTo(oracle, request, linkTokenFee);
  }

  function verifyLookupData(bytes memory data, bytes4 fulfillSelector)
    external
    returns (bytes32 requestId)
  {
    Chainlink.Request memory request = buildChainlinkRequest(
      jobIdLookup,
      address(this),
      fulfillSelector
    );

    request.add('data', string(data));
    // request.add('endpoint', 'lookup.json');

    return sendChainlinkRequestTo(oracle, request, linkTokenFee);
  }

  function withdrawLink() external {
    require(msg.sender == owner);
    uint256 balance = IERC20(linkToken).balanceOf(address(this));
    IERC20(linkToken).transfer(msg.sender, balance);
  }
}
