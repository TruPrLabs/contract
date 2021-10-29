const hre = require('hardhat');

async function deploy() {
  const EscrowPlatform = await ethers.getContractFactory('PrivateEscrow');
  const contract = await EscrowPlatform.deploy();
  await contract.deployed();

  console.log('Escrow contract deployed to:', contract.address);
}

deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
