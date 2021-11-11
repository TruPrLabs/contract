//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';

import '@chainlink/contracts/src/v0.8/ChainlinkClient.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './IEscrow.sol';

// Note: Switch when testing
import './APIConsumer.sol';

// import {MockChainlinkConsumer as ChainlinkConsumer} from './test/MockConsumer.sol';

// struct MileStoneTask {
//     ;
// }

enum Status {
    CLOSED,
    OPEN,
    FULFILLED
}

// enum TaskType {
//     PERSONALISED,
//     PUBLIC,
//     PRIVATE
// }

struct Task {
    Status status;
    address sponsor;
    address promoter;
    address erc20Token;
    uint256 depositAmount;
    uint256 timeWindowStart;
    uint256 timeWindowEnd;
    uint256 vestingTerm;
    ScoreFn.Data payoutRate;
    string data;
}

// Chainlink responses

enum ResponseStatus {
    FAILURE,
    SUCCESS,
    ERROR
}

library ScoreFn {
    struct Data {
        bool linear;
        uint64[] x;
        uint64[] y;
    }

    uint256 constant MAX_VALUE = type(uint64).max;

    function evaluate(
        Data memory self,
        uint64 x,
        uint256 multiplier
    ) external pure returns (uint256) {
        // requires: x[-1] == MAX_VALUE
        if (x == MAX_VALUE) {
            if (self.y[self.y.length - 1] == MAX_VALUE) return multiplier;
            return (((multiplier >> 64) * self.y[self.y.length - 1]) / MAX_VALUE) << 64; // guard against overflow
        }
        // follows: x < MAX_VALUE

        uint256 i;
        // requires: x[i] < x[i+1]
        // requires: x[-1] == MAX_VALUE
        while (x < self.x[i]) i++;
        // follows:  i <= x.length

        // requires: y.length == x.length
        uint64 y0 = (i == 0) ? 0 : self.y[i - 1]; // implicit 0 added

        if (!self.linear) return y0; // return left value for piecewise-continuous functions

        uint64 y1 = self.y[i];

        uint64 x0 = (i == 0) ? 0 : self.x[i - 1]; // implicit 0 added
        uint64 x1 = self.x[i];

        // calculate in lower precision to avoid overflow
        return (((multiplier >> 64) * (y0 + (uint256(y1) * (x - x0)) / (x1 - x0))) / MAX_VALUE) << 64;
    }
}

// ==================================
// ====== Escrow Base Contract ======
// ==================================

contract EscrowBase is IEscrow, ChainlinkConsumer, Ownable {
    // ====================== Storage ========================

    uint256 public baseFeePerMille = 50; // per mille; fee given to platform
    uint256 public taskCount = 0; // XXX: Why did Sablier start at 10 000? https://github.com/sablierhq/sablier/blob/develop/packages/protocol/contracts/Sablier.sol

    mapping(uint256 => Task) internal tasks;
    mapping(uint256 => ScoreFn.Data) internal payoutRates;
    mapping(uint256 => mapping(address => uint256)) lastPayout;

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

    function getAllTasks() public view returns (Task[] memory) {
        Task[] memory _tasks = new Task[](taskCount);
        for (uint256 i; i < taskCount; i++) {
            _tasks[i] = tasks[i];
        }
        return _tasks;
    }

    // ====================== Core API ========================

    // function createTask(
    //     bool linearRate,
    //     // TaskType taskType,
    //     address promoter,
    //     address erc20Token,
    //     uint256 depositAmount,
    //     uint256 timeWindowStart,
    //     uint256 timeWindowEnd,
    //     uint64 vestingTerm,
    //     uint64[] calldata xticks,
    //     uint64[] calldata yticks,
    //     string calldata data
    // ) external {
    //     require(block.timestamp < timeWindowEnd && timeWindowStart < timeWindowEnd, 'invalid timeframe given');
    //     require(vestingTerm <= 60 * 60 * 24 * 28, 'vestingTerm cannot be longer than 28 days'); // to avoid deposit lockup
    //     require(tokenWhitelist[erc20Token], 'token is not whitelisted');
    //     require(depositAmount > 0, 'depositAmount cannot be 0');
    //     require(promoter != msg.sender, 'promoter cannot be sender');

    //     require(xticks.length == yticks.length, 'ticks must have same length');
    //     require(xticks[xticks.length - 1] == ScoreFn.MAX_VALUE, 'xticks must end at max value');

    //     if (xticks.length > 1) {
    //         for (uint256 i = 1; i < xticks.length; i++)
    //             require(xticks[i - 1] < xticks[i] && yticks[i - 1] < yticks[i], 'ticks must be increasing');
    //     }

    //     bool success = IERC20(erc20Token).transferFrom(msg.sender, address(this), depositAmount);
    //     require(success, 'ERC20 Token could not be transferred');

    //     uint256 taskId = taskCount++;
    // }

    // function _addTask(
    //     uint256 taskId,
    //     bool linearRate,
    //     address promoter,
    //     address erc20Token,
    //     uint256 depositAmount,
    //     uint256 timeWindowStart,
    //     uint256 timeWindowEnd,
    //     string calldata data
    // ) external {
    //     tasks[taskId] = Task({
    //         status: Status.OPEN,
    //         // taskType: taskType,
    //         sponsor: msg.sender,
    //         promoter: promoter,
    //         erc20Token: erc20Token,
    //         depositAmount: depositAmount,
    //         timeWindowStart: timeWindowStart,
    //         timeWindowEnd: timeWindowEnd,
    //         data: data
    //     });
    // }

    // function _addPayoutRate(
    //     uint256 taskId,
    //     bool linearRate,
    //     address promoter,
    //     address erc20Token,
    //     uint256 depositAmount,
    //     uint256 timeWindowStart,
    //     uint256 timeWindowEnd,
    //     string calldata data
    // ) external {
    //     payoutRate[taskId] = ScoreFn.Data()
    // }

    function createTask(
        bool linearRate,
        address promoter,
        address erc20Token,
        uint256 depositAmount,
        uint256 timeWindowStart,
        uint256 timeWindowEnd,
        uint64 vestingTerm,
        uint64[] memory xticks,
        uint64[] memory yticks,
        string memory data
    ) external {
        require(block.timestamp < timeWindowEnd && timeWindowStart < timeWindowEnd, 'invalid timeframe given');
        require(vestingTerm <= 60 * 60 * 24 * 28, 'vestingTerm cannot be longer than 28 days'); // to avoid deposit lockup
        require(tokenWhitelist[erc20Token], 'token is not whitelisted');
        require(depositAmount > 0, 'depositAmount cannot be 0');
        require(promoter != msg.sender, 'promoter cannot be sender');

        require(xticks.length == yticks.length, 'ticks must have same length');
        require(xticks[xticks.length - 1] == ScoreFn.MAX_VALUE, 'xticks must end at max value');

        if (xticks.length > 1) {
            for (uint256 i = 1; i < xticks.length; i++)
                require(xticks[i - 1] < xticks[i] && yticks[i - 1] < yticks[i], 'ticks must be increasing');
        }

        bool success = IERC20(erc20Token).transferFrom(msg.sender, address(this), depositAmount);
        require(success, 'ERC20 Token could not be transferred');

        uint256 taskId = taskCount++;

        ScoreFn.Data memory payoutRate = ScoreFn.Data(linearRate, xticks, yticks);

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

    function setTokenWhitelisted(address token, bool allowed) external onlyOwner {
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

contract TruPr is EscrowBase {
    using ScoreFn for ScoreFn.Data;

    constructor(address oracle, address[] memory tokenWhitelist) EscrowBase(oracle, tokenWhitelist) {}

    // ====================== User API ========================

    function fulfillTask(uint256 taskId) external {
        Task storage task = tasks[taskId];

        require(task.promoter == msg.sender, 'caller is not the promoter');
        require(task.status == Status.OPEN, 'task is not open');
        require(
            task.timeWindowStart <= block.timestamp && block.timestamp < task.timeWindowEnd,
            'not in valid time window'
        );

        verifyTask(
            taskId,
            task.timeWindowStart,
            task.timeWindowEnd,
            task.vestingTerm,
            task.data,
            this.fulfillTaskCallback.selector
        );
    }

    // function calculateRewards()

    function cancelTask(uint256 taskId) external {
        Task storage task = tasks[taskId];

        require(task.status == Status.OPEN, 'task is not open');

        if (msg.sender == task.promoter) {
            // promoter is allowed to cancel any time
            // TODO: calculate remaining funds, transfer to sponsor; reward promoter?
        }
        if (msg.sender == task.sponsor) {
            require(
                block.timestamp < task.timeWindowStart || task.timeWindowEnd + task.vestingTerm < block.timestamp,
                'must be before or after valid time window plus vesting term'
            );
            verifyTask(
                taskId,
                task.timeWindowStart,
                task.timeWindowEnd,
                task.vestingTerm,
                task.data,
                this.fulfillTaskCallback.selector
            );
        }
    }

    // function revokeTask(uint taskId) external {
    //     Task storage task = tasks[taskId];

    //     require(msg.sender == task.sponsor, 'caller is not the sponsor');
    //     require(task.status == Status.OPEN, 'task is not open');
    //     require(
    //         block.timestamp < task.timeWindowStart || task.timeWindowEnd < block.timestamp,
    //         'must be before or after valid time window'
    //     );

    //     bytes memory data = abi.encode(taskId, task);
    //     verifyTask(data, this.revokeTaskCallback.selector);
    // }

    // ================== Chainlink Callbacks ====================

    function fulfillTaskCallback(
        bytes32 requestId,
        uint256 taskId,
        uint64 score,
        ResponseStatus response
    ) external recordChainlinkFulfillment(requestId) {
        Task storage task = tasks[taskId];

        // require(task.status == Status.OPEN, 'task is not open'); // XXX: is it ok to let chainlink calls fail?

        if (task.status == Status.OPEN && response == ResponseStatus.SUCCESS) {
            if (task.promoter == address(0)) {
                // task is public
                // TODO: chainlink node needs to be able to pass in promoter
                // Risks: User could change address if stored in bio.. Could user change their twitter id?
            }

            // evaluate the piecewise-linear / constant payout function, given the current score and the total deposit
            uint256 totalReward = task.payoutRate.evaluate(score, task.depositAmount);
            uint256 remainingReward = totalReward - lastPayout[taskId][task.promoter]; // ensures that totalReward >= last

            task.status = Status.FULFILLED;

            payoutTo(task.promoter, task.erc20Token, remainingReward);
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
