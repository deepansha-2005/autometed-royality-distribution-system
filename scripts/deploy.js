// scripts/deploy.js
const hre = require("hardhat");

async function main() {
  console.log("Deploying Automated Royalty Distribution System...");

  const RoyaltyDistribution = await hre.ethers.getContractFactory("RoyaltyDistribution");
  const royaltyDistribution = await RoyaltyDistribution.deploy();

  await royaltyDistribution.waitForDeployment();
  
  const address = await royaltyDistribution.getAddress();
  console.log("RoyaltyDistribution deployed to:", address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
