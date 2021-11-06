const hre = require('hardhat');

const { now, delta10h, delta10d, future10m, future10h, future50h } = require('./time');

async function deploy() {
  [owner, promoter, ...signers] = await ethers.getSigners();

  // Token
  const Erc20MockToken = await ethers.getContractFactory('ERC20Mock');
  const token = await Erc20MockToken.deploy('MockToken', 'MOCK');
  await token.deployed();
  console.log('deployed token 1');

  const token2 = await Erc20MockToken.deploy('BananaToken', 'BANA');
  await token2.deployed();

  console.log('Erc20Mock contract1 deployed to:', token.address);
  console.log('Erc20Mock contract2 deployed to:', token2.address);

  let tx;
  tx = await token.mintFor(owner.address, '1000');
  await tx.wait();
  tx = await token2.mintFor(promoter.address, '1000');
  await tx.wait();

  // Treasury
  const TreasuryFactory = await ethers.getContractFactory('Treasury');
  const treasury = await TreasuryFactory.deploy();
  await treasury.deployed();

  console.log('Treasury deployed to:', treasury.address);

  // Escrow Platform
  const EscrowPlatform = await ethers.getContractFactory('PrivateEscrow');
  const contract = await EscrowPlatform.deploy(
    '0x000000000000000000000000000000000000dEaD', //oracle
    [token.address, token2.address],
    treasury.address
  );
  await contract.deployed();

  console.log('Escrow contract deployed to:', contract.address);

  console.log('Creating test tasks');

  tx = await token.approve(contract.address, ethers.constants.MaxUint256);
  await tx.wait();

  tx = await contract.createTask(
    '0',
    promoter.address,
    '28405',
    token.address,
    '100',
    future10m,
    future50h,
    delta10h,
    '0x68656c6c6f000000000000000000000000000000000000000000000000000000'
  );
  await tx.wait();

  tx = await token2.connect(promoter).approve(contract.address, ethers.constants.MaxUint256);
  await tx.wait();

  tx = await contract
    .connect(promoter)
    .createTask(
      0,
      owner.address,
      '28405',
      token2.address,
      500,
      future10h,
      future50h,
      delta10d,
      '0x68656c6c6f000000000000000000000000000000000000000000000000000000'
    );

  await tx.wait();
}

deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
