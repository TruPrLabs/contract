//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';

import '@chainlink/contracts/src/v0.8/ChainlinkClient.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './IEscrow.sol';

// Note: Switch when testing
// import {ChainlinkConsumer} from './APIConsumer.sol';
import {MockChainlinkConsumer as ChainlinkConsumer} from './test/MockConsumer.sol';

enum Status {
    CLOSED,
    OPEN
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
    uint256 balance;
    uint256 timeWindowStart;
    uint256 timeWindowEnd;
    uint256 vestingTerm;
    ScoreFnData payoutRate;
    string data;
}

// Chainlink responses

enum ResponseStatus {
    INVALID,
    SUCCESS,
    ERROR
}

struct ScoreFnData {
    bool linear;
    uint256[] x;
    uint256[] y;
}

// ==================================
// ====== Escrow Base Contract ======
// ==================================

contract EscrowBase is IEscrow, ChainlinkConsumer, Ownable {
    // ====================== Storage ========================
    uint256 constant MAX_SCORE = 100;

    uint256 public MaxVestingTerm = 60 * 60 * 24 * 28; // 28 days
    uint256 public MaxTimeWindow = 60 * 60 * 24 * 28 * 12 * 2; // 2 years
    uint256 public PendingRevokeDelay = 60 * 60 * 24; // 1 day

    uint256 public baseFeePerMille = 50; // fee given to platform
    uint256 public taskCount = 0; // XXX: Why did Sablier start at 10 000? https://github.com/sablierhq/sablier/blob/develop/packages/protocol/contracts/Sablier.sol

    mapping(uint256 => Task) public tasks;
    mapping(uint256 => mapping(address => uint256)) totalPayout;
    mapping(uint256 => uint256) public pendingRevoke;

    mapping(address => bool) private tokenWhitelist;
    mapping(address => uint256) treasury;

    constructor(address oracle, address[] memory _tokenWhitelist) ChainlinkConsumer(oracle) {
        for (uint256 i = 0; i < _tokenWhitelist.length; i++) tokenWhitelist[_tokenWhitelist[i]] = true;
    }

    // ====================== Getters ========================

    function getStatus(uint256 taskId) external view returns (Status) {
        return tasks[taskId].status;
    }

    function getAllTasks() external view returns (Task[] memory) {
        Task[] memory _tasks = new Task[](taskCount);
        for (uint256 i; i < taskCount; i++) {
            _tasks[i] = tasks[i];
        }
        return _tasks;
    }

    function isPendingRevoke(uint256 taskId) external view returns (bool time) {
        return pendingRevoke[taskId] > 0;
    }

    // hypothetical rewards, given score, assuming it can be fulfilled
    function calculateRewards(
        uint256 taskId,
        address who,
        uint256 score
    ) external view returns (uint256) {
        Task storage task = tasks[taskId];
        uint256 accumulatedRewards = evaluateScore(task.payoutRate, score);
        return accumulatedRewards - totalPayout[taskId][who];
    }

    // ====================== Setters ========================

    function setMaxVestingTerm(uint256 term) external onlyOwner {
        MaxVestingTerm = term;
    }

    function setMaxTimeWindow(uint256 time) external onlyOwner {
        MaxTimeWindow = time;
    }

    function setPendingRevokeDelay(uint256 delay) external onlyOwner {
        PendingRevokeDelay = delay;
    }

    function setBaseFee(uint256 feePerMille) external onlyOwner {
        require(feePerMille <= 50, 'fee cannot be larger than 5%');
        baseFeePerMille = feePerMille;
    }

    function setTokenWhitelisted(address token, bool allowed) external onlyOwner {
        tokenWhitelist[token] = allowed;
    }

    // ====================== Core API ========================

    function createTask(
        bool linearRate,
        address promoter,
        address erc20Token,
        uint256 depositAmount,
        uint256 timeWindowStart,
        uint256 timeWindowEnd,
        uint256 vestingTerm,
        uint256[] memory xticks,
        uint256[] memory yticks,
        string memory data
    ) external {
        require(
            block.timestamp < timeWindowEnd &&
                timeWindowStart < timeWindowEnd &&
                timeWindowEnd - timeWindowStart <= MaxTimeWindow,
            'invalid time frame given'
        );
        require(vestingTerm <= MaxVestingTerm, 'vestingTerm cannot be longer than 28 days'); // to avoid deposit lockup
        require(tokenWhitelist[erc20Token], 'token is not whitelisted');
        require(depositAmount > 0, 'depositAmount cannot be 0');
        require(promoter != msg.sender, 'promoter cannot be sender');

        require(xticks.length == yticks.length, 'ticks must have same length');
        require(xticks[xticks.length - 1] == MAX_SCORE, 'xticks must end at max value');
        require(yticks[yticks.length - 1] <= depositAmount, 'total payout cannot be greater than depositAmount');

        if (xticks.length > 1)
            for (uint256 i = 1; i < xticks.length; i++)
                require(xticks[i - 1] < xticks[i] && yticks[i - 1] < yticks[i], 'ticks must be increasing');

        bool success = IERC20(erc20Token).transferFrom(msg.sender, address(this), depositAmount);
        require(success, 'ERC20 Token could not be transferred');

        uint256 taskId = taskCount++;

        ScoreFnData memory payoutRate = ScoreFnData(linearRate, xticks, yticks);

        tasks[taskId] = Task({
            status: Status.OPEN,
            sponsor: msg.sender,
            promoter: promoter,
            erc20Token: erc20Token,
            depositAmount: depositAmount,
            balance: depositAmount,
            timeWindowStart: timeWindowStart,
            timeWindowEnd: timeWindowEnd,
            vestingTerm: vestingTerm,
            payoutRate: payoutRate,
            data: data
        });

        emit TaskCreated(taskId, msg.sender, promoter);
    }

    // ====================== Internal ========================

    // NOTE: maybe better to keep inline in fulfill
    function payoutPromoter(uint256 taskId, uint256 score) internal {
        Task storage task = tasks[taskId];

        assert(task.promoter != address(0)); // disregarding public promotrions for now

        // console.log('task.balance', task.balance);
        // evaluate the piecewise-linear / constant payout function, given the current score and the total deposit
        uint256 accumulatedRewards = evaluateScore(task.payoutRate, score);
        uint256 pendingReward = accumulatedRewards - totalPayout[taskId][task.promoter]; // also ensures that accumulatedRewards >= last

        // console.log('pendingReward', pendingReward);
        // shouldn't be required (except for public case)
        require(pendingReward <= task.balance, 'payout cannot be larger than balance');
        task.balance -= pendingReward;

        // task.status = Status.FULFILLED;
        totalPayout[taskId][task.promoter] = accumulatedRewards;

        uint256 platformFee = (pendingReward * baseFeePerMille) / 1000;
        uint256 reward = pendingReward - platformFee;

        treasury[task.erc20Token] += platformFee;

        bool transferSuccessful = IERC20(task.erc20Token).transfer(task.promoter, reward);
        require(transferSuccessful, 'ERC20 Token could not be transferred');
    }

    // ====================== Misc ========================

    function withdrawToken(address token) external onlyOwner {
        bool transferSuccessful = IERC20(token).transfer(owner(), treasury[token]);
        require(transferSuccessful, 'ERC20 Token could not be transferred');
    }

    function withdraw() external onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}('');
        require(success, 'balance could not be transferred');
    }

    function evaluateScore(ScoreFnData memory self, uint256 x) public pure returns (uint256) {
        // requires: x[-1] == MAX_SCORE
        if (x == MAX_SCORE) return self.y[self.y.length - 1];

        // follows: x < MAX_SCORE

        uint256 i;
        // requires: x[i] < x[i+1]
        // requires: x[-1] == MAX_SCORE
        while (self.x[i] < x) i++;
        // follows:  i <= x.length

        // requires: y.length == x.length
        uint256 y0 = (i == 0) ? 0 : self.y[i - 1]; // implicit 0 added

        if (!self.linear) return y0; // return left value for piecewise-continuous functions

        uint256 y1 = self.y[i];

        uint256 x0 = (i == 0) ? 0 : self.x[i - 1]; // implicit 0 added
        uint256 x1 = self.x[i];

        return y0 + (y1 * (x - x0)) / (x1 - x0);
    }

    function testScores(uint256 taskId) public view returns (uint256[] memory) {
        ScoreFnData memory self = tasks[taskId].payoutRate;

        uint256 num = MAX_SCORE;
        uint256[] memory res = new uint256[](num + 1);
        for (uint256 i; i <= num; i++) {
            // console.log('it', i);
            uint256 resi = evaluateScore(self, i);
            // console.log('res', resi);
            res[i] = resi;
        }
        return res;
    }

    // function evaluateScores(
    //     ScoreFnData memory self,
    //     uint64[] memory xs
    // ) public pure returns (uint256[] memory) {
    //     uint256[] memory res = new uint256[](xs.length);
    //     for (uint256 i; i < xs.length; i++) {
    //         res[i] = evaluateScore(self, xs[i]);
    //     }
    //     return res;
    // }
}

// ==================================
// ============== TruPr =============
// ==================================

contract TruPr is EscrowBase {
    constructor(address oracle, address[] memory tokenWhitelist) EscrowBase(oracle, tokenWhitelist) {}

    // ====================== User API ========================

    function fulfillTask(uint256 taskId) external {
        Task storage task = tasks[taskId];

        require(task.status == Status.OPEN, 'task is not open');
        require(task.promoter == msg.sender, 'caller is not the promoter');
        require(
            task.timeWindowStart <= block.timestamp && block.timestamp <= task.timeWindowEnd,
            'must be in valid time window'
        );

        _verifyTask(
            taskId,
            task.timeWindowStart,
            task.timeWindowEnd,
            task.vestingTerm,
            task.data,
            this.fulfillTaskCallback.selector
        );
    }

    function fulfillTaskPublic(uint256 taskId, string memory authentication) external {
        Task storage task = tasks[taskId];

        require(task.status == Status.OPEN, 'task is not open');
        require(task.promoter == address(0), 'task is not public');
        require(
            task.timeWindowStart <= block.timestamp && block.timestamp <= task.timeWindowEnd,
            'must be in valid time window'
        );

        _verifyTaskPublic(
            taskId,
            task.timeWindowStart,
            task.timeWindowEnd,
            task.vestingTerm,
            task.data,
            authentication,
            this.fulfillTaskCallback.selector
        );
    }

    // a task can only be cancelled by the sponsor if there's no chance a promoter
    // can still fulfill the task and then not receive any rewards
    // could add pending state + time delay during time window
    function cancelTask(uint256 taskId) external {
        Task storage task = tasks[taskId];

        require(task.status == Status.OPEN, 'task is not open');
        require(msg.sender == task.sponsor || msg.sender == task.promoter, 'caller must be sponsor or promoter');

        // promoter is allowed to cancel any time
        // sponsor must wait for a buffered time without chainlink verification
        if (msg.sender == task.sponsor) {
            require(
                block.timestamp < task.timeWindowStart ||
                    task.timeWindowEnd + task.vestingTerm + PendingRevokeDelay < block.timestamp,
                'must be in valid cancellation period'
            );
        }

        uint256 remainingBalance = task.balance;
        task.balance = 0;
        task.status = Status.CLOSED;
        // NOTE: could free up whole task struct and get gas refund

        bool transferSuccessful = IERC20(task.erc20Token).transfer(task.sponsor, remainingBalance);
        require(transferSuccessful, 'ERC20 Token could not be transferred');
    }

    function requestRevokeTask(uint256 taskId) external {
        Task memory task = tasks[taskId];

        require(task.sponsor == msg.sender, 'caller is not the sponsor');
        require(task.status == Status.OPEN, 'task is not open');
        require(pendingRevoke[taskId] == 0, 'revoke already pending');

        pendingRevoke[taskId] = block.timestamp;
        // task.status = Status.PENDING_REVOKE;
    }

    // this function can be called by the sponsor inside the time frame
    // calls the chainlink api and requires a score of 0 (post deleted etc.)
    // should add time delay as a safety measure
    function revokeTask(uint256 taskId) external {
        Task memory task = tasks[taskId];

        require(task.sponsor == msg.sender, 'caller is not the sponsor');
        require(task.status == Status.OPEN, 'task is not open');
        require(0 < pendingRevoke[taskId], 'revoke must be pending');
        require(pendingRevoke[taskId] + PendingRevokeDelay <= block.timestamp, 'must wait for revoke delay to pass');

        pendingRevoke[taskId] = 0;

        _verifyTask(
            taskId,
            task.timeWindowStart,
            task.timeWindowEnd,
            task.vestingTerm,
            task.data,
            this.revokeTaskCallback.selector
        );
    }

    // ================== Chainlink Callbacks ====================

    function fulfillTaskCallback(
        bytes32 requestId,
        uint256 taskId,
        uint256 score,
        ResponseStatus response
    ) external recordChainlinkFulfillment(requestId) {
        Task storage task = tasks[taskId];

        if (task.status == Status.OPEN && response == ResponseStatus.SUCCESS) {
            task.status = Status.CLOSED;
            payoutPromoter(taskId, score);
        }
    }

    function revokeTaskCallback(
        bytes32 requestId,
        uint256 taskId,
        uint256 score,
        ResponseStatus response
    ) external recordChainlinkFulfillment(requestId) {
        Task storage task = tasks[taskId];

        if (task.status == Status.OPEN && response == ResponseStatus.INVALID) {
            uint256 remainingBalance = task.balance;
            task.balance = 0;
            task.status = Status.CLOSED;

            bool transferSuccessful = IERC20(task.erc20Token).transfer(task.sponsor, remainingBalance);
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
