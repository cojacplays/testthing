const hre = require("hardhat");

async function main() {
  // Contract configuration
  const AAVE_POOL_ADDRESS_PROVIDER = "YOUR_AAVE_POOL_ADDRESS_PROVIDER";
  const UNISWAP_ROUTER = "YOUR_UNISWAP_ROUTER";
  const SUSHISWAP_ROUTER = "YOUR_SUSHISWAP_ROUTER";
  const MIN_PROFIT_THRESHOLD = ethers.utils.parseEther("0.1"); // 0.1 ETH minimum profit
  const SLIPPAGE_TOLERANCE = 50; // 0.5%

  // Get the contract factory
  const FlashLoanArbitrage = await hre.ethers.getContractFactory("FlashLoanArbitrage");
  
  // Deploy the contract
  const flashLoanArbitrage = await FlashLoanArbitrage.deploy(
    AAVE_POOL_ADDRESS_PROVIDER,
    UNISWAP_ROUTER,
    SUSHISWAP_ROUTER,
    MIN_PROFIT_THRESHOLD,
    SLIPPAGE_TOLERANCE
  );

  await flashLoanArbitrage.deployed();

  console.log("FlashLoanArbitrage deployed to:", flashLoanArbitrage.address);
  console.log("Configuration:");
  console.log("- AAVE Pool Address Provider:", AAVE_POOL_ADDRESS_PROVIDER);
  console.log("- Uniswap Router:", UNISWAP_ROUTER);
  console.log("- SushiSwap Router:", SUSHISWAP_ROUTER);
  console.log("- Minimum Profit Threshold:", ethers.utils.formatEther(MIN_PROFIT_THRESHOLD), "ETH");
  console.log("- Slippage Tolerance:", SLIPPAGE_TOLERANCE / 100, "%");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });