import {BigNumber} from '@ethersproject/bignumber';
import {formatUnits, parseUnits} from '@ethersproject/units';
import {constants} from 'ethers';
import {TransactionResponse} from '@ethersproject/providers';
import {ethers} from 'hardhat';

async function main() {
  const lottery = await ethers.getContract('Lottery');
  const PrizeReservePool = await ethers.getContract('PrizeReservePool');
  const ticket = await ethers.getContract('Ticket');
  const timer = await ethers.getContract('Timer');
  const iron = await ethers.getContract('MockIRON');
  const [owner, , , , alice, bob] = await ethers.getSigners();
  const vrf = await ethers.getContract('MockVRFCoordinator');
  const rand = await ethers.getContract('RandomNumberGenerator');

  const printBalance = async (address: string, tag: string) => {
    const bl = await iron.balanceOf(address);
    console.log(`${tag}: ${formatUnits(bl, 18)}`);
  };

  vrf.once('RandomnessRequest', console.log.bind(console, 'RandomnessRequest'));

  await iron.transfer(alice.address, parseUnits('100', 18));
  await iron.transfer(bob.address, parseUnits('100', 18));
  await iron.transfer(PrizeReservePool.address, parseUnits('30000', 18));
  await iron.connect(alice).approve(lottery.address, constants.MaxUint256);
  await iron.connect(bob).approve(lottery.address, constants.MaxUint256);

  const startTime = Math.floor(Date.now() / 1000);
  const closeTime = startTime + 60 * 30;
  await lottery.updateLottoSettings(35, 24, [800000, 100000, 100000, 0], parseUnits('1', 18), parseUnits('2000', 18));
  await timer.setCurrentTime(startTime);
  await lottery.updateDefaultDuration(60);
  await lottery.manualStartLotto(startTime, closeTime);
  console.log('buy ticket : \n');
  await printBalance(alice.address, 'alice');
  await printBalance(bob.address, 'bob');
  await lottery.connect(alice).batchBuyLottoTicket(1, 2, [2, 5, 1, 6, 3, 1, 5, 4, 2, 6]);
  await lottery.connect(bob).batchBuyLottoTicket(1, 2, [2, 1, 5, 3, 4, 2, 5, 1, 6, 4]);
  await lottery.connect(bob).batchBuyLottoTicket(1, 2, [1, 2, 3, 4, 1, 1, 2, 3, 6, 1]);
  await lottery.connect(bob).batchBuyLottoTicket(1, 2, [7, 6, 5, 3, 4, 5, 4, 3, 1, 6]);
  await lottery.connect(bob).batchBuyLottoTicket(1, 2, [7, 6, 5, 3, 8, 7, 6, 5, 1, 4]);
  console.log('after buy ticket : \n');
  await printBalance(alice.address, 'alice');
  await printBalance(bob.address, 'bob');
  await timer.setCurrentTime(closeTime + 1);
  // let tx = (await lottery.drawWinningNumbers(1, BigNumber.from(12345))) as TransactionResponse;
  // let receipt = (await tx.wait()) as any;
  // const requestId1 = receipt.events[1].args.requestId;

  // console.log('First request', requestId1);

  const a = await ticket.countMatch(1, 35, [29, 14, 13, 26, 4]);
  console.log('countmatch', a);
  const test = await ticket.countMatch(1, 35, [7, 6, 5, 3, 4]);
  console.log('countmatch', test);

  // tx = (await lottery.retryDrawWinningNumbers(1, BigNumber.from(12345))) as TransactionResponse;
  // receipt = (await tx.wait()) as any;
  // const requestId2 = receipt.events[1].args.requestId;
  // console.log('Second request', requestId2);

  // await vrf.callBackWithRandomness(requestId1, BigNumber.from('87563245875694312'), rand.address);
  // console.log('After request 1 callback:', (await lottery.getCurrentLotto()).winningNumbers);

  // await vrf.callBackWithRandomness(
  //   requestId2,
  //   'e1ac82e75d0be47d11499f6f3c896e73c928d0fc56dd3854cf656fee42d22e22a825aca84fbe9b3e9cb49d4bd90b73e31b7dafad5680d933ac1f76bac4db88cd6c0a1ea3503ade73398efa92de48c88269a11bb7cc216be9397909c71dcf9c5c58c02a2da0e7a0b9c7e22b44091be3c188c175f29fa03c1f3b5812958e0804f414ec827f20416fde596a25edfc88702d17dc28369042dc911987bed6a9d09a6fb92c30924e08d781415ea5e1815d1c010ab7f96541a09020dae4a098536589d8eb582f72e860326cb523a344d932f338d49ff87e3f9ffd6850c2fcd79f18d1f0000000000000000000000000e992c68523d35e74ccacfdc4f52fae68e589e348a762f616cef54808f0adea43059231457263614bbde8f3ceef0a25453d93311dd5a74ecf7f53edbd2a9bfa902d9025fc40a0df73670630b5242b1b0163e8410174be3bc8c7f9bb60ba62f28caa6a160fc40be52dddf21e59a34ff762f11ef5fcc0f20301231344cf5779debe4ef3b784436473fed070375e9b115f483418976cc027079d0175e64bc7e01ac201930f937c256e49dea3e252905638a800677c250000000000000000000000000000000000000000000000000000000000724862',
  //   rand.address
  // );
  // console.log('winning numbers : \n');
  // const lotteryInfo = await lottery.getCurrentLotto();

  // console.log('winning numbers:', lotteryInfo.winningNumbers);
  // console.log('winners:', lotteryInfo.winners);
  // console.log('prize pool:', lotteryInfo.prizePool);

  // await lottery.connect(alice).claimReward(1, 2);
  // await lottery.connect(bob).claimReward(1, 3).catch(console.error);
  // console.log('after claim : \n');
  // await printBalance(alice.address, 'alice');
  // await printBalance(bob.address, 'bob');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
