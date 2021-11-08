//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@chainlink/contracts/src/v0.8/ChainlinkClient.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import 'hardhat/console.sol';

import '../IEscrow.sol';

contract ChainlinkConsumer {
    address private linkToken = 0xa36085F69e2889c224210F603D836748e7dC0088;

    constructor(address _oracle) {}

    modifier recordChainlinkFulfillment(bytes32 requestId) {
        _;
    }

    function verifyTimelineData(bytes memory data, bytes4 fulfillSelector) internal {
        mockFulfill(data, fulfillSelector);
    }

    function verifyLookupData(bytes memory data, bytes4 fulfillSelector) internal {
        mockFulfill(data, fulfillSelector);
    }

    function mockFulfill(bytes memory data, bytes4 fulfillSelector) internal {
        (uint256 taskId, IEscrow.Task memory t) = abi.decode(data, (uint256, IEscrow.Task));
        (bool success, bytes memory returnData) = address(this).call(
            abi.encodeWithSelector(fulfillSelector, 0, taskId, true)
        );
        require(success, 'could not call fulfillSelector');
    }

    function withdrawLink() external {
        uint256 balance = IERC20(linkToken).balanceOf(address(this));
        IERC20(linkToken).transfer(msg.sender, balance);
    }
}

contract TestChainlinkConsumer is ChainlinkClient {
    using Chainlink for Chainlink.Request;

    address private oracle = 0xDe2Fa809f8E0c702983C846Becd044c24B86C3EE;

    bytes32 private jobIdTest = bytes32('ec7d958e15a44c48adcf1d927f0069cb');

    bool public lastsuccess;

    mapping(uint256 => bool) public fulfilled;

    function test() external returns (bytes32 requestId) {
        // uint256 a = 1234;
        // address b = 0x000000000000000000000000000000000000dead;
        // bytes memory data = abi.encode(a, b);

        Chainlink.Request memory request = buildChainlinkRequest(jobIdTest, address(this), this.fulfill.selector);
        // request.addBytes('data', data);
        request.addUint('taskId', 666);
        request.addUint('promoterId', 1234);
        request.addUint('timeWindowStart', block.timestamp);
        request.addUint('timeWindowEnd', block.timestamp + 1000);
        request.addUint('duration', 88888888);
        request.add('taskHash', '0x1234569999999999999999999999999999999999999999999999999999999999');

        // return sendOperatorRequestTo(oracle, request, 0.1 ether);
        return sendChainlinkRequestTo(oracle, request, 0.1 ether);
    }

    function fulfill(
        bytes32 requestId,
        // uint256 taskId,
        bool success
    ) external {
        // fulfilled[taskId] = success;
        lastsuccess = success;
    }

    function setLastSuccess(bool _suc) external {
        lastsuccess = _suc;
    }
}
