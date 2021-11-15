const hre = require('hardhat');

const { centerTime } = require('../scripts/time.js');
var time = centerTime();

async function deploy() {
  [owner, promoter, ...signers] = await ethers.getSigners();

  // Token
  const MOCKERC20Token = await ethers.getContractFactory('MOCKERC20');
  const token1 = await MOCKERC20Token.deploy('MockToken', 'MOCK');
  await token1.deployed();

  const token2 = await MOCKERC20Token.deploy('BananaToken', 'BANA');
  await token2.deployed();

  console.log('MOCKERC20 contract1 deployed to:', token1.address);
  console.log('MOCKERC20 contract2 deployed to:', token2.address);

  let tx;
  tx = await token1.mintFor(owner.address, '1000000');
  await tx.wait();
  tx = await token2.mintFor(promoter.address, '1000');
  await tx.wait();

  // // Treasury
  // const TreasuryFactory = await ethers.getContractFactory('Treasury');
  // const treasury = await TreasuryFactory.deploy();
  // await treasury.deployed();

  // console.log('Treasury deployed to:', treasury.address);

  // Escrow Platform
  const EscrowPlatform = await ethers.getContractFactory('TruPr');
  const contract = await EscrowPlatform.deploy(
    '0xa07463D2C0bDb92Ec9C49d6ffAb59b864A48A660', // oracle
    [token1.address, token2.address]
    // treasury.address
  );
  await contract.deployed();

  console.log('Escrow contract deployed to:', contract.address);

  console.log('Creating test tasks');

  tx = await token1.approve(contract.address, ethers.constants.MaxUint256);
  await tx.wait();

  tx = await contract.createTask(
    promoter.address,
    token1.address,
    100,
    time.future10m,
    time.future50h,
    time.delta10d,
    true,
    [100],
    [100],
    'test content data'
  );
  await tx.wait();

  tx = await contract.createTask(
    ethers.constants.AddressZero, // make it public
    token1.address,
    50000,
    time.future10m,
    time.future50h,
    time.delta10d,
    true,
    [10, 40, 100],
    [3, 5, 15],
    'test content data'
  );
  await tx.wait();

  tx = await token2.connect(promoter).approve(contract.address, ethers.constants.MaxUint256);
  await tx.wait();

  tx = await contract
    .connect(promoter)
    .createTask(
      owner.address,
      token2.address,
      666,
      time.future10d,
      time.future50d,
      time.delta1d,
      true,
      [100],
      [666],
      'test content data2'
    );
  await tx.wait();

  console.log();
  console.log(`const contractAddressKovan = '${contract.address}';`);
  console.log(`const mockToken1Kovan = '${token1.address}';`);
  console.log(`const mockToken2Kovan = '${token2.address}';`);
}

deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
