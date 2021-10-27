const hre = require('hardhat');

async function main() {
  const Erc20MockToken = await ethers.getContractFactory('ERC20Mock');
  const token = await Erc20MockToken.deploy();
  await token.deployed();

  const EscrowPlatform = await ethers.getContractFactory('PrivateEscrow');
  const contract = await EscrowPlatform.deploy();
  await contract.deployed();

  console.log('Escrow contract deployed to:', contract.address);
  console.log('Erc20Mock contract deployed to:', token.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
