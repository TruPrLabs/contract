const { expect } = require('chai');
const { ethers, network } = require('hardhat');
const { BigNumber, utils } = require('ethers');

const { centerTime } = require('../scripts/time.js');

const BN = BigNumber.from;

var time = centerTime();

const jumpToTime = async (t) => {
  await network.provider.send('evm_mine', [t]);
  time = centerTime(t);
};

const MaxUint256 = ethers.constants.MaxUint256;

const getLatestBlockTimestamp = async () => {
  let blocknum = await network.provider.request({ method: 'eth_blockNumber' });
  let block = await network.provider.request({ method: 'eth_getBlockByNumber', params: [blocknum, true] });
  return BN(block.timestamp).toString();
};

describe('Escrow Platform', () => {
  let EscrowPlatform;
  let contract;
  let token;

  let owner;
  let sponsor;
  let promoter;

  let signers;

  let tx;
  let receipt;
  let log;

  let taskId;

  beforeEach(async () => {
    //  = await ethers.getContractFactory('TruPr');
    TruPr = await ethers.getContractFactory('TruPr');
    ERC20Token = await ethers.getContractFactory('MOCKERC20');

    [owner, sponsor, promoter, ...signers] = await ethers.getSigners();

    token = await ERC20Token.deploy('MockToken', 'MOCK');
    await token.deployed();

    contract = await TruPr.deploy(
      '0x000000000000000000000000000000000000dEaD', //oracle
      [token.address] // whitelist
      // '0x000000000000000000000000000000000000dEaD' //treasury
    );
    contract = contract.connect(sponsor);

    token = token.connect(sponsor);
    // token.mintFor(sponsor.address, 1000);
    token.mintFor(sponsor.address, BN('0xffffffffffffffffffffffffffffffffffffffffffffffff').add(20));
    token.approve(contract.address, MaxUint256);
  });

  it('Create tasks correctly', async () => {
    tx = await contract.createTask(
      0,
      promoter.address,
      token.address,
      100,
      time.now,
      time.future1m,
      0,
      [MaxUint256],
      [100],
      'test'
    );

    receipt = await tx.wait();
    log = receipt.events.at(-1);

    expect(log.event).to.equal('TaskCreated');

    taskId = log.args.taskId;

    let task = await contract.getTask(taskId);

    expect(taskId).to.equal(BN('0'));

    expect(task.status).to.equal(1);
    expect(task.sponsor).to.equal(sponsor.address);
    expect(task.promoter).to.equal(promoter.address);
    expect(task.erc20Token).to.equal(token.address);
    expect(task.depositAmount).to.equal(100);
    expect(task.balance).to.equal(100);
    expect(task.timeWindowStart).to.equal(time.now);
    expect(task.timeWindowEnd).to.equal(time.future1m);
    expect(task.vestingTerm).to.equal(0);
    expect(task.data).to.equal('test');
  });

  it('Task creation conditions', async () => {
    await expect(
      contract.createTask(
        0,
        promoter.address,
        token.address,
        100,
        time.future1m,
        time.now,
        0,
        [MaxUint256],
        [100],
        'test'
      )
    ).to.be.revertedWith('invalid timeframe given');

    await expect(
      contract.createTask(0, promoter.address, token.address, 0, time.now, time.future1m, 0, [MaxUint256], [0], 'test')
    ).to.be.revertedWith('depositAmount cannot be 0');

    await expect(
      contract.createTask(
        0,
        sponsor.address,
        token.address,
        100,
        time.now,
        time.future1m,
        0,
        [MaxUint256],
        [100],
        'test'
      )
    ).to.be.revertedWith('promoter cannot be sender');
  });

  // describe('Payout rate', async () => {
  //   beforeEach(async () => {
  //     tx = await contract.createTask(
  //       1,
  //       promoter.address,
  //       token.address,
  //       100,
  //       time.future1m,
  //       time.future10m,
  //       0,
  //       [BN('0xffffffffffff'), MaxUint256],
  //       [90, 100],
  //       'test'
  //     );
  //     receipt = await tx.wait();
  //     taskId = receipt.events.at(-1).args.taskId;
  //   });

  //   // it('plot payout rate', async () => {
  //   //   let res = await contract.testScores(0);
  //   //   console.log(res);
  //   // });
  // });

  describe('Fulfill task logic', async () => {
    beforeEach(async () => {
      tx = await contract.createTask(
        0,
        promoter.address,
        token.address,
        100,
        time.future1m,
        time.future10m,
        0,
        [MaxUint256],
        [100],
        'test'
      );
      receipt = await tx.wait();
      taskId = receipt.events.at(-1).args.taskId;
    });

    it("promoter can't fulfill outside of time window", async () => {
      // too early
      await expect(contract.connect(promoter).fulfillTask(taskId)).to.be.revertedWith('not in valid time window');

      // advance to after time window
      jumpToTime(time.future1h);

      // too late
      await expect(contract.connect(promoter).fulfillTask(taskId)).to.be.revertedWith('not in valid time window');
    });

    it('only promoter is able to fulfill only once', async () => {
      // advance into time window
      jumpToTime(time.future1m);

      // only promoter can fulfill task
      await expect(contract.connect(sponsor).fulfillTask(taskId)).to.be.revertedWith('caller is not the promoter');
      await expect(contract.connect(signers[0]).fulfillTask(taskId)).to.be.revertedWith('caller is not the promoter');

      // promoter is able to fulfill
      await contract.setCallbackData(0, 1); // set score 0, valid response
      tx = await contract.connect(promoter).fulfillTask(taskId);
      await tx.wait();

      // can't fulfill again
      await expect(contract.connect(promoter).fulfillTask(taskId)).to.be.revertedWith('task is not open');
    });

    it('only sponsor can revoke task before expiration only once', async () => {
      // only sponsor can revoke
      await expect(contract.connect(promoter).revokeTask(taskId)).to.be.revertedWith('caller is not the sponsor');

      // sponsor can revoke (before start)
      await contract.revokeTask(taskId);
      // XXX: count balances

      // sponsor can't revoke twice
      await expect(contract.revokeTask(taskId)).to.be.revertedWith('task is not open');
    });

    it('sponsor can revoke task after expiration, promoter cannot fulfill revoked task', async () => {
      // advance into to after time window
      jumpToTime(time.future1h);

      // sponsor can revoke (after end)
      await contract.revokeTask(taskId);

      // promoter can't fulfill revoked task
      await expect(contract.connect(promoter).fulfillTask(taskId)).to.be.revertedWith('task is not open');
    });

    it('promoter cannot fulfill revoked task', async () => {
      // advance into to after time window
      jumpToTime(time.future1h);

      await contract.revokeTask(taskId);

      // can't fulfill after task is revoked
      await expect(contract.connect(promoter).fulfillTask(taskId)).to.be.revertedWith('task is not open');
    });
  });
});
