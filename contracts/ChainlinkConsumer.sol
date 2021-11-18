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

    bytes32 private jobIdPersonalized = bytes32('c1c46f2f90cb41d5b9306b469fa35ec9');
    bytes32 private jobIdPublic = bytes32('d795c25e51534ae39a6b0f81cf32779c');
    bytes32 private jobIdPrivate = bytes32('e8c67225f3e14191b8e8b5ef5bd5cf45');

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
        Chainlink.Request memory request = buildChainlinkRequest(jobIdPersonalized, address(this), fulfillSelector);

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
        string memory userId,
        bytes4 fulfillSelector
    ) internal {
        Chainlink.Request memory request = buildChainlinkRequest(jobIdPublic, address(this), fulfillSelector);

        request.addUint('taskId', taskId);
        request.addUint('startDate', startDate);
        request.addUint('endDate', endDate);
        request.addUint('cliff', cliff);
        request.add('userAddress', addressToString(msg.sender));
        request.add('userId', userId);
        request.add('taskData', taskData);

        sendChainlinkRequestTo(oracle, request, fee);
    }

    function addressToString(address _address) public pure returns (string memory) {
        bytes32 _bytes = bytes32(uint256(uint160(_address)));
        bytes memory HEX = '0123456789abcdef';
        bytes memory _string = new bytes(42);
        _string[0] = '0';
        _string[1] = 'x';
        for (uint256 i = 0; i < 20; i++) {
            _string[2 + i * 2] = HEX[uint8(_bytes[i + 12] >> 4)];
            _string[3 + i * 2] = HEX[uint8(_bytes[i + 12] & 0x0f)];
        }
        return string(_string);
    }

    function withdrawLink() external {
        require(msg.sender == owner);
        uint256 balance = IERC20(linkToken).balanceOf(address(this));
        IERC20(linkToken).transfer(msg.sender, balance);
    }
}
