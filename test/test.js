const { expect } = require('chai');
const { ethers } = require('hardhat');
const { BigNumber } = require('ethers');

const { now, future10s, future1m, future1h, delta1m } = require('../scripts/time.js');

const BN = BigNumber.from;

describe('Escrow Platform', function () {
  let EscrowPlatform;
  let contract;
  let token;

  let owner;
  let sponsor;
  let promoter;

  let signers;

  beforeEach(async function () {
    EscrowPlatform = await ethers.getContractFactory('PrivateEscrow');
    Erc20MockToken = await ethers.getContractFactory('ERC20Mock');

    [owner, sponsor, promoter, ...signers] = await ethers.getSigners();

    token = await Erc20MockToken.deploy('MockToken', 'MOCK');

    contract = await EscrowPlatform.deploy(
      '0x000000000000000000000000000000000000dEaD', //oracle
      [token.address], // whitelist
      '0x000000000000000000000000000000000000dEaD' //treasury
    );
    contract = contract.connect(sponsor);

    token = token.connect(sponsor);
    token.mintFor(sponsor.address, 1000);
    token.approve(contract.address, ethers.constants.MaxUint256);
  });

  it('Create tasks correctly', async function () {
    let tx = await contract.createTask(
      0,
      promoter.address,
      6789,
      token.address,
      100,
      now,
      future1m,
      delta1m,
      ethers.constants.HashZero
    );

    let receipt = await tx.wait();
    let log = receipt.events.at(-1);

    expect(log.event).to.equal('TaskCreated');

    let { taskId } = log.args;

    let task = await contract.getTask(taskId);

    expect(taskId).to.equal(BN('0'));

    expect(task.sponsor).to.equal(sponsor.address);
    expect(task.promoter).to.equal(promoter.address);
    expect(task.promoterUserId).to.equal(6789);
    expect(task.erc20Token).to.equal(token.address);
    expect(task.depositAmount).to.equal(100);
  });

  it('Task creation conditions', async function () {
    await expect(
      contract.createTask(
        0,
        promoter.address,
        6789,
        token.address,
        100,
        future1m,
        now,
        delta1m,
        ethers.constants.HashZero
      )
    ).to.be.revertedWith('timeWindowEnd is before timeWindowStart');

    await expect(
      contract.createTask(
        0,
        promoter.address,
        6789,
        token.address,
        0,
        now,
        future1m,
        delta1m,
        ethers.constants.HashZero
      )
    ).to.be.revertedWith('depositAmount cannot be 0');

    await expect(
      contract.createTask(
        0,
        sponsor.address,
        6789,
        token.address,
        100,
        now,
        future1m,
        delta1m,
        ethers.constants.HashZero
      )
    ).to.be.revertedWith('promoter cannot be sender');
  });

  it('Allow promoter to fulfill', async function () {
    let tx = await contract.createTask(
      0,
      promoter.address,
      6789,
      token.address,
      100,
      now,
      future1m,
      delta1m,
      ethers.constants.HashZero
    );

    await tx.wait();

    tx = await contract.connect(promoter).fulfillTask('0');
    console.log(tx);
    let receipt = await tx.wait();
    console.log(receipt);
  });
});
