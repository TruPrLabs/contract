const hre = require('hardhat');

const { now, delta10h, delta10d, future10m, future10h, future50h } = require('./time');

async function deploy() {
  [owner, promoter, ...signers] = await ethers.getSigners();

  const Erc20MockToken = await ethers.getContractFactory('ERC20Mock');
  const token = await Erc20MockToken.deploy('MockToken', 'MOCK');
  await token.deployed();

  const token2 = await Erc20MockToken.deploy('BananaToken', 'BANA');
  await token2.deployed();

  console.log('Erc20Mock contract1 deployed to:', token.address);
  console.log('Erc20Mock contract2 deployed to:', token2.address);

  let tx;
  tx = await token.mint(owner.address, '1000');
  await tx.wait();
  tx = await token2.mint(promoter.address, '1000');
  await tx.wait();

  const EscrowPlatform = await ethers.getContractFactory('PrivateEscrow');
  const contract = await EscrowPlatform.deploy();
  await contract.deployed();

  console.log('Escrow contract deployed to:', contract.address);

  tx = await token.approve(contract.address, ethers.constants.MaxUint256);
  await tx.wait();

  tx = await contract.createTask(
    '0',
    promoter.address,
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
