const { expect } = require('chai');
const { ethers } = require('hardhat');
const { BigNumber } = require('ethers');

const BN = BigNumber.from;

/**
 * Parses transaction events from the logs in a transaction receipt
 * @param {TransactionReceipt} receipt Transaction receipt containing the events in the logs
 * @returns {{[eventName: string]: TransactionEvent}}
 */
// private getTransactionEvents(receipt: TransactionReceipt): {[eventName: string]: TransactionEvent}
// {
//     const txEvents: {[eventName: string]: TransactionEvent}  = {}

//     // for each log in the transaction receipt
//     for (const log of receipt.logs)
//     {
//         // for each event in the ABI
//         for (const abiEvent of Object.values(this.contract.interface.events))
//         {
//             // if the hash of the ABI event equals the tx receipt log
//             if (abiEvent.topics[0] == log.topics[0])
//             {
//                 // Parse the event from the log topics and data
//                 txEvents[abiEvent.name] = abiEvent.parse(log.topics, log.data)

//                 // stop looping through the ABI events
//                 break
//             }
//         }
//     }

//     return txEvents
// }

describe('Escrow Platform', function () {
  let iface;
  let EscrowPlatform;
  let contract;
  let token;

  let owner;
  let sponsor;
  let promoter;
  let signers;

  // time
  let delta1s = 1 * 1000;
  let delta1m = 1 * 1000 * 60;
  let delta1h = 1 * 1000 * 60 * 60;

  let now;
  let future10s;
  let future1m;
  let future1h;

  beforeEach(async function () {
    EscrowPlatform = await ethers.getContractFactory('PrivateEscrow');
    Erc20MockToken = await ethers.getContractFactory('ERC20Mock');

    [owner, sponsor, promoter, ...signers] = await ethers.getSigners();

    iface = EscrowPlatform.interface;
    contract = await EscrowPlatform.deploy();
    contract = contract.connect(sponsor);

    token = await Erc20MockToken.deploy('MockToken', 'MOCK');
    token = token.connect(sponsor);
    token.mint(sponsor.address, 1000);
    token.approve(contract.address, ethers.constants.MaxUint256);

    now = new Date().getTime();
    future10s = now + 10 * delta1s;
    future1m = now + 1 * delta1m;
    future1h = now + 1 * delta1h;

    // owner = await contract.owner();
    // console.log('address', token.address);
  });

  it('Should be able to create tasks', async function () {
    let tx = await contract.createTask(
      0,
      promoter.address,
      token.address,
      100,
      future10s,
      future1m,
      delta1m,
      ethers.constants.HashZero
    );

    // let filt = contract.filters.TaskCreated(null, signer1.address, null);
    // contract.on(filt, console.log);

    let receipt = await tx.wait();
    let log = receipt.events.at(-1);

    expect(log.event).to.equal('TaskCreated');

    let { taskId } = log.args;

    let task = await contract.getTask(taskId);

    expect(taskId).to.equal(BN('0'));

    expect(task.sponsor).to.equal(sponsor.address);
    expect(task.promoter).to.equal(promoter.address);
    expect(task.erc20Token).to.equal(token.address);
    expect(task.depositAmount).to.equal(100);
    // ...

    let sponsorFunds = await contract.outstandingPayment(0, sponsor.address);
    let promoterFunds = await contract.outstandingPayment(0, promoter.address);

    expect(sponsorFunds).to.equal(100);
    expect(promoterFunds).to.equal(0);
  });
});
