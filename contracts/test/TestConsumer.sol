//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@chainlink/contracts/src/v0.8/ChainlinkClient.sol';

contract TestChainlinkConsumer is ChainlinkClient {
    using Chainlink for Chainlink.Request;

    address private oracle = 0xDe2Fa809f8E0c702983C846Becd044c24B86C3EE;

    uint256 private fee = 0.1 * 10**18;

    constructor() {
        setPublicChainlinkToken();
    }

    bytes32 private jobIdTest = bytes32('ec7d958e15a44c48adcf1d927f0069cb');

    bool public lastsuccess;

    mapping(uint256 => bool) public fulfilled;

    function test() external returns (bytes32 requestId) {
        // uint a = 1234;
        // address b = 0x000000000000000000000000000000000000dead;
        // bytes memory data = abi.encode(a, b);

        Chainlink.Request memory request = buildChainlinkRequest(jobIdTest, address(this), this.fulfill.selector);
        // request.addBytes('data', data);
        request.addUint('taskId', 666);
        request.add('promoterId', '1234');
        request.addUint('timeWindowStart', block.timestamp);
        request.addUint('timeWindowEnd', block.timestamp + 1000);
        request.addUint('duration', 88888888);
        request.add('taskHash', '0x123456999999999999999999999999999999999999999999');

        return sendChainlinkRequestTo(oracle, request, fee);
    }

    function fulfill(
        bytes32 requestId,
        uint256 taskId,
        bool success
    ) external {
        // fulfilled[taskId] = success;
        lastsuccess = success;
    }

    function setLastSuccess(bool _suc) external {
        lastsuccess = _suc;
    }
}
