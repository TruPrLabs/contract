//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract IEscrow {
  event TaskCreated(uint256 indexed taskId, address indexed sponsor, address indexed promoter);

  enum Platform {
    TWITTER,
    REDDIT,
    INSTAGRAM,
    DISCORD
  }

  enum Status {
    CLOSED,
    OPEN,
    FULFILLED
  }

  struct Task {
    Status status;
    Platform platform;
    address sponsor;
    address promoter;
    uint256 promoterUserId;
    address erc20Token;
    uint256 depositAmount;
    uint256 timeWindowStart; // verify that using timestamps is "safe" (https://eips.ethereum.org/EIPS/eip-1620)
    uint256 timeWindowEnd;
    uint256 persistenceDuration;
    bytes32 taskHash;
  }
}
