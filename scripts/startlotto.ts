import { BigNumber } from '@ethersproject/bignumber';
import { formatUnits, parseUnits } from '@ethersproject/units';
import { constants } from 'ethers';
import { TransactionResponse } from '@ethersproject/providers';
import { ethers } from 'hardhat';

async function main() {
  const [owner] = await ethers.getSigners();
  const lottery = await ethers.getContract('Lottery', owner);
  const prizeReservePool = await ethers.getContract('PrizeReservePool', owner);
  const iron = await ethers.getContract('MockIRON', owner);
  await iron.mint(prizeReservePool.address, parseUnits('1000000', 18));
  const start = Math.floor(Date.now() / 1000);
  const end = start + 30*60;
  await lottery.manualStartLotto(start, end)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
