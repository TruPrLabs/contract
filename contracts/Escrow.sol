//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';

import '@chainlink/contracts/src/v0.8/ChainlinkClient.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './IEscrow.sol';

// Note: Switch when testing
// import './APIConsumer.sol';
import {MockChainlinkConsumer as ChainlinkConsumer} from './test/MockConsumer.sol';

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

enum Metric {
    LIKES,
    RETWEETS,
    COMMENTS
}

struct TaskSpecs {
    Status status;
    Platform platform;
    address sponsor;
    address promoter;
    uint256 promoterUserId;
    address erc20Token;
    uint256 depositAmount;
    uint256 timeWindowStart; // verify that using timestamps is "safe" (https://eips.ethereum.org/EIPS/eip-1620)
    uint256 timeWindowEnd;
}

struct MileStoneTask {
    Metric metric;
    bool linear;
    bool isPublic;
    uint256 delay;
    uint256[] ticks;
    uint256[] values;
    bytes32 taskHash;
    string data;
}

// ==================================
// ====== Escrow Base Contract ======
// ==================================

contract Escrow is IEscrow, ChainlinkConsumer, Ownable {
    // ====================== Storage ========================

    uint256 public baseFeePerMille = 50; // per mille; fee given to platform
    uint256 public taskCount = 0; // XXX: Why did Sablier start at 10 000? https://github.com/sablierhq/sablier/blob/develop/packages/protocol/contracts/Sablier.sol

    mapping(uint256 => Task) internal tasks;
    mapping(address => bool) private tokenWhitelist;
    mapping(address => uint256) balances;

    constructor(address oracle, address[] memory _tokenWhitelist) ChainlinkConsumer(oracle) {
        for (uint256 i = 0; i < _tokenWhitelist.length; i++) {
            tokenWhitelist[_tokenWhitelist[i]] = true;
        }
    }

    // ====================== Getters ========================

    function getStatus(uint256 taskId) external view returns (Status) {
        return tasks[taskId].status;
    }

    function getTask(uint256 taskId) public view returns (Task memory) {
        return tasks[taskId];
    }

    function getAllTasks() public view returns (Task[] memory _tasks) {
        _tasks = new Task[](taskCount);
        for (uint256 i = 0; i < taskCount; i++) {
            _tasks[i] = tasks[i];
        }
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
        uint256 delay,
        bytes32 taskHash
    ) external payable {
        require(
            block.timestamp < timeWindowEnd && timeWindowStart < timeWindowEnd,
            'timeWindowEnd is before timeWindowStart'
        );
        require(tokenWhitelist[erc20Token], 'token is not whitelisted');
        require(depositAmount > 0, 'depositAmount cannot be 0');
        require(promoter != msg.sender, 'promoter cannot be sender');

        bool success = IERC20(erc20Token).transferFrom(msg.sender, address(this), depositAmount);
        require(success, 'ERC20 Token could not be transferred');

        uint256 taskId = taskCount++;

        tasks[taskId] = Task({
            status: Status.OPEN,
            platform: platform,
            sponsor: msg.sender,
            promoter: promoter,
            promoterUserId: promoterUserId,
            erc20Token: erc20Token,
            depositAmount: depositAmount,
            timeWindowStart: timeWindowStart,
            timeWindowEnd: timeWindowEnd,
            delay: delay,
            taskHash: taskHash
        });

        emit TaskCreated(taskId, msg.sender, promoter);
    }

    // NOTE: maybe better to keep inline in fulfill
    function payoutTo(
        address promoter,
        address token,
        uint256 amount
    ) internal {
        uint256 platformFee = (amount * baseFeePerMille) / 1000;
        uint256 reward = amount - platformFee;

        balances[token] += platformFee;

        bool transferSuccessful = IERC20(token).transfer(promoter, reward);
        require(transferSuccessful, 'ERC20 Token could not be transferred');
    }

    // ====================== Misc ========================

    function setFee(uint256 feePerMille) external onlyOwner {
        require(feePerMille <= 50, 'fee cannot be larger than 5%');
        baseFeePerMille = feePerMille;
    }

    function setWhitelistToken(address token, bool allowed) external onlyOwner {
        tokenWhitelist[token] = allowed;
    }

    function withdrawToken(address token) external onlyOwner {
        bool transferSuccessful = IERC20(token).transfer(owner(), balances[token]);
        require(transferSuccessful, 'ERC20 Token could not be transferred');
    }

    function withdraw() external onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}('');
        require(success, 'balance could not be transferred');
    }
}

// ==================================
// === PersonalisedEscrow Contract ==
// ==================================

contract PersonalisedEscrow is Escrow {
    constructor(address oracle, address[] memory tokenWhitelist) Escrow(oracle, tokenWhitelist) {}

    // ====================== User API ========================

    function fulfillTask(uint256 taskId) external {
        Task storage task = tasks[taskId];

        require(msg.sender == task.promoter, 'caller is not the promoter');
        require(task.status == Status.OPEN, 'task is not open');
        require(
            task.timeWindowStart <= block.timestamp && block.timestamp < task.timeWindowEnd,
            'not in valid time window'
        );

        bytes memory data = abi.encode(taskId, task);
        verifyTimelineData(data, this.fulfillTaskCallback.selector);
    }

    function revokeTask(uint256 taskId) external {
        Task storage task = tasks[taskId];

        require(msg.sender == task.sponsor, 'caller is not the sponsor');
        require(task.status == Status.OPEN, 'task is not open');
        require(
            block.timestamp < task.timeWindowStart || task.timeWindowEnd < block.timestamp,
            'must be before or after valid time window'
        );

        bytes memory data = abi.encode(taskId, task);
        verifyTimelineData(data, this.revokeTaskCallback.selector);
    }

    // ================== Chainlink Callbacks ====================

    function fulfillTaskCallback(
        bytes32 requestId,
        uint256 taskId,
        bool success
    ) external recordChainlinkFulfillment(requestId) {
        Task storage task = tasks[taskId];

        require(task.status == Status.OPEN, 'task is not open'); // XXX: is it ok to let chainlink calls fail?

        if (success) {
            task.status = Status.FULFILLED;

            payoutTo(task.promoter, task.erc20Token, task.depositAmount);
        }
    }

    function revokeTaskCallback(
        bytes32 requestId,
        uint256 taskId,
        bool success
    ) external recordChainlinkFulfillment(requestId) {
        Task storage task = tasks[taskId];

        require(task.status == Status.OPEN, 'task is not open');

        if (success) {
            task.status = Status.CLOSED;

            bool transferSuccessful = IERC20(task.erc20Token).transfer(task.sponsor, task.depositAmount);
            require(transferSuccessful, 'ERC20 Token could not be transferred');
        }
    }
}

// utils
function min(uint256 a, uint256 b) pure returns (uint256) {
    return a < b ? a : b;
}

function max(uint256 a, uint256 b) pure returns (uint256) {
    return a > b ? a : b;
}
