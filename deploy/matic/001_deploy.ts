import {DeployFunction} from 'hardhat-deploy/types';
import 'hardhat-deploy-ethers';
import 'hardhat-deploy';
import {parseUnits} from '@ethersproject/units';
import {constants} from 'ethers';

const run: DeployFunction = async (hre) => {
  const {deployments, getNamedAccounts} = hre;
  const {deploy, execute} = deployments;
  const {creator} = await getNamedAccounts();
  console.log('Creator', creator);

  const link = {address: '0xb0897686c545045aFc77CF20eC7A532E3120E0F1'};
  const vrfCoordinator = {address: '0x3d2341ADb2D31f1c5530cDC622016af293177AE0'};
  const keyHash = '0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da';
  const vrfFee = parseUnits('0.0001', 18);
  const titan = {address: '0xaAa5B9e6c589642f98a1cDA99B9D024B8407285A'};

  const lottery = await deploy('Lottery', {
    from: creator,
    log: true,
    args: [constants.AddressZero],
  });

  const prizeReservePool = await deploy('PrizeReservePool', {
    from: creator,
    log: true,
    args: [titan.address, lottery.address],
  });

  const taxService = await deploy('TaxService', {
    from: creator,
    log: true,
    args: [],
  });

  const ticket = await deploy('Ticket', {
    contract: 'Ticket',
    from: creator,
    log: true,
    args: ['http://api.titandao.finance/lottery/tickets/{id}.json', lottery.address],
  });

  const randomGen = await deploy('RandomNumberGenerator', {
    from: creator,
    log: true,
    args: [vrfCoordinator.address, link.address, lottery.address, keyHash, vrfFee],
  });

  await execute(
    'Lottery',
    {from: creator, log: true},
    'initialize',
    titan.address,
    ticket.address,
    randomGen.address,
    prizeReservePool.address,
    taxService.address,
    creator
  );
  await execute(
    'TaxService',
    {from: creator, log: true},
    'initialize',
    titan.address,
    lottery.address,
    prizeReservePool.address
  );
  await execute('Lottery', {from: creator, log: true}, 'setTaxRate', 300000);

  await execute(
    'Lottery',
    {from: creator, log: true},
    'updateLottoSettings',
    8,
    4,
    [600000, 300000, 100000, 0],
    parseUnits('1000', 18), // 1M Titan
    parseUnits('100000', 18) // 100M Titan
  );
};

run.tags = ['matic'];

run.skip = async (hre) => {
  return hre.network.name !== 'matic';
};

export default run;
