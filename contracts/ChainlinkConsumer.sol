//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@chainlink/contracts/src/v0.8/ChainlinkClient.sol';
// import './chainlinkv0.8/ChainlinkClient.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import 'hardhat/console.sol';

// import './ITruPr.sol';

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
        uint256 startDate,
        uint256 endDate,
        uint256 cliff,
        string memory taskData,
        bytes4 fulfillSelector
    ) internal {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), fulfillSelector);

        request.addUint('taskId', taskId);
        request.addUint('startDate', startDate);
        request.addUint('endDate', endDate);
        request.addUint('cliff', cliff);
        request.add('taskData', taskData);

        sendChainlinkRequestTo(oracle, request, fee);
    }

    function _verifyTaskPublic(
        uint256 taskId,
        uint256 startDate,
        uint256 endDate,
        uint256 cliff,
        string memory taskData,
        string memory userData,
        bytes4 fulfillSelector
    ) internal {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), fulfillSelector);

        request.addUint('taskId', taskId);
        request.addUint('startDate', startDate);
        request.addUint('endDate', endDate);
        request.addUint('cliff', cliff);
        request.addUint('userAddress', uint256(uint160(msg.sender)));
        request.add('userData', userData);
        request.add('taskData', taskData);

        sendChainlinkRequestTo(oracle, request, fee);
    }

    function withdrawLink() external {
        require(msg.sender == owner);
        uint256 balance = IERC20(linkToken).balanceOf(address(this));
        IERC20(linkToken).transfer(msg.sender, balance);
    }
}
