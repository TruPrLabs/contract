//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@chainlink/contracts/src/v0.8/ChainlinkClient.sol';
// import './chainlinkv0.8/ChainlinkClient.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import 'hardhat/console.sol';

import './IEscrow.sol';

contract ChainlinkConsumer is ChainlinkClient {
    address private owner;

    using Chainlink for Chainlink.Request;

    address private oracle;
    address private linkToken = 0xa36085F69e2889c224210F603D836748e7dC0088;

    bytes32 private jobId = bytes32('e5ce0aaf603d4aa2be36b62bb296ce96');

    uint256 private fee = 0.1 ether;

    constructor(address _oracle) {
        owner = msg.sender;
        oracle = _oracle;
        setPublicChainlinkToken();
    }

    function _verifyTask(
        uint256 taskId,
        uint256 timeWindowStart,
        uint256 timeWindowEnd,
        uint256 vestingTerm,
        string memory data,
        bytes4 fulfillSelector
    ) internal {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), fulfillSelector);

        request.addUint('taskId', taskId);
        request.addUint('timeWindowStart', timeWindowStart);
        request.addUint('timeWindowEnd', timeWindowEnd);
        request.addUint('vestingTerm', vestingTerm);
        request.add('data', data);

        sendChainlinkRequestTo(oracle, request, fee);
    }

    function _verifyTaskPublic(
        uint256 taskId,
        uint256 timeWindowStart,
        uint256 timeWindowEnd,
        uint256 vestingTerm,
        string memory data,
        string memory authentication,
        bytes4 fulfillSelector
    ) internal {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), fulfillSelector);

        request.addUint('taskId', taskId);
        request.addUint('timeWindowStart', timeWindowStart);
        request.addUint('timeWindowEnd', timeWindowEnd);
        request.addUint('vestingTerm', vestingTerm);
        request.add('authentication', authentication);
        request.add('data', data);

        sendChainlinkRequestTo(oracle, request, fee);
    }

    function withdrawLink() external {
        require(msg.sender == owner);
        uint256 balance = IERC20(linkToken).balanceOf(address(this));
        IERC20(linkToken).transfer(msg.sender, balance);
    }
}
