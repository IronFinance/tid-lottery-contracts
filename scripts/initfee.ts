/* eslint-disable prefer-const */
import { parseUnits } from '@ethersproject/units';
import {ethers} from 'hardhat';

async function main() {
  const [owner] = await ethers.getSigners();
  console.log('Account balance:', (await owner.getBalance()).toString());
  const iron = await ethers.getContract('MockIRON', owner);
  const user = '0x03DbFDC27697b311B38C1934c38bD97905C46Ed0';
  await iron.mint(user, parseUnits('19000', 18));
  await owner.sendTransaction({to: user, value:parseUnits('100', 18)});
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
