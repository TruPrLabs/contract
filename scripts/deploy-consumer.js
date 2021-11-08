const hre = require('hardhat');

const { centerTime } = require('./time.js');
var time = centerTime();

async function deploy() {
  [owner, promoter, ...signers] = await ethers.getSigners();

  // Escrow Platform
  const TestConsumer = await ethers.getContractFactory('TestChainlinkConsumer');
  const contract = await TestConsumer.deploy();
  await contract.deployed();

  console.log('Test Consumer contract deployed to:', contract.address);

  const interface = ['function transfer(address recipient, uint256 amount)'];
  const linkToken = new ethers.Contract('0xa36085F69e2889c224210F603D836748e7dC0088', interface, owner);
  await linkToken.transfer(contract.address, ethers.utils.parseEther('1').toString());

  console.log('link token transferred');
}

deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
