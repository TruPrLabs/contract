//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';

import '@chainlink/contracts/src/v0.8/ChainlinkClient.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './APIConsumer.sol';

contract IEscrow {
  event TaskCreated(uint256 indexed taskId, address indexed sponsor, address indexed promoter);
}

contract Escrow is IEscrow {
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
    uint256 persistenceDuration; // after the conditions have been fulfilled, how long until the promoter receives all the funds (ensures that it is not taken down)
    bytes32 promotionHash; // hash to verify against
  }

  // ====================== Core API ========================

  function createTask(
    Platform platform,
    address promoter,
    uint256 promoterUserId,
    address erc20Token,
    uint256 depositAmount,
    uint256 timeWindowStart,
    uint256 timeWindowEnd,
    uint256 persistenceDuration,
    bytes32 promotionHash
  ) external payable {
    require(
      block.timestamp < timeWindowEnd && timeWindowStart < timeWindowEnd,
      'timeWindowEnd is before timeWindowStart'
    );
    require(persistenceDuration > 0, 'persistenceDuration must be greater 0');
    require(depositAmount > 0, 'depositAmount cannot be 0');
    require(promoter != msg.sender, 'promoter cannot be sender');

    bool success = IERC20(erc20Token).transferFrom(msg.sender, address(this), depositAmount);
    require(success, 'ERC20 Token could not be transferred');

    tasks[taskCount] = Task({
      status: Status.OPEN,
      platform: platform,
      sponsor: msg.sender,
      promoter: promoter,
      promoterUserId: promoterUserId,
      erc20Token: erc20Token,
      depositAmount: depositAmount,
      timeWindowStart: timeWindowStart,
      timeWindowEnd: timeWindowEnd,
      persistenceDuration: persistenceDuration,
      promotionHash: promotionHash
    });

    emit TaskCreated(taskCount, msg.sender, promoter);

    taskCount++;
  }

  // // XXX: should use a library for this
  // function min(uint256 a, uint256 b) internal pure returns (uint256) {
  //     return a < b ? a : b;
  // }

  // function max(uint256 a, uint256 b) internal pure returns (uint256) {
  //     return a > b ? a : b;
  // }
}

contract PrivateEscrow is Escrow, APIConsumer {
  address public owner;

  // Escrow
  address[] private tokenWhitelist;
  uint256 public baseFee = 50; // per mille; fee given to platform
  uint256 public taskCount = 0; // XXX: Why did Sablier start at 10 000? https://github.com/sablierhq/sablier/blob/develop/packages/protocol/contracts/Sablier.sol

  mapping(uint256 => Task) private tasks;

  /**
   * Network: Kovan
   * Oracle: 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8 (Chainlink Devrel
   * Node)
   * Job ID: d5270d1c311941d0b08bead21fea7747
   * Fee: 0.1 LINK
   */
  constructor(address[] memory _tokenWhitelist) {
    owner = msg.sender;
    tokenWhitelist = _tokenWhitelist;
  }

  // ====================== Getters ========================

  function getStatus(uint256 taskId) external view returns (Status) {
    return tasks[taskId].status;
  }

  function getTask(uint256 taskId) public view returns (Task memory) {
    return tasks[taskId];
  }

  function getAllTasks() public view returns (Task[] memory _tasks) {
    // Task[] memory _tasks = new Task[](taskCount);
    for (uint256 i = 0; i < taskCount; i++) {
      _tasks[i] = tasks[i];
    }
  }

  // ====================== User API ========================

  function fulfillTask(uint256 taskId, bytes[] memory urlProof) external {
    Task storage task = tasks[taskId];
    require(task.status == Status.OPEN, 'task is not open');
    require(
      task.timeWindowStart <= block.timestamp && block.timestamp < task.timeWindowEnd,
      'not in valid time window'
    );

    bytes memory data = abi.encode(task);
    this.verifyTimelineData(data, this.fulfilTaskCallback.selector);
  }

  // TODO: change chainlink callback to pass a requestId
  function fulfilTaskCallback(
    bytes32 requestId,
    uint256 taskId,
    bool success
  ) external recordChainlinkFulfillment(requestId) {
    Task storage task = tasks[taskId];

    if (success && task.status == Status.OPEN) {
      task.status = Status.FULFILLED;

      bool transferSuccessful = IERC20(task.erc20Token).transfer(task.promoter, task.depositAmount);
      require(transferSuccessful, 'ERC20 Token could not be transferred');
    }
  }

  function revokeTask(uint256 taskId) external {
    Task storage task = tasks[taskId];
    require(task.status == Status.OPEN, 'task is not open');
    require(
      block.timestamp < task.timeWindowStart || task.timeWindowEnd < block.timestamp,
      'must be before or after valid time window'
    );

    bytes memory data = abi.encode(task);
    this.verifyTimelineData(data, this.revokeTaskCallback.selector);
  }

  function revokeTaskCallback(
    bytes32 requestId,
    uint256 taskId,
    bool success
  ) external recordChainlinkFulfillment(requestId) {
    Task storage task = tasks[taskId];

    if (success && task.status == Status.OPEN) {
      task.status = Status.CLOSED;

      bool transferSuccessful = IERC20(task.erc20Token).transfer(task.sponsor, task.depositAmount);
      require(transferSuccessful, 'ERC20 Token could not be transferred');
    }
  }

  //
}
