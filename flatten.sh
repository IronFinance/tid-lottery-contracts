#!/bin/bash

# npx hardhat flatten ./contracts/Lottery.sol 2>&1 | tee ./flattens/Lottery_flatten.sol
# npx hardhat flatten ./contracts/PrizeReservePool.sol 2>&1 | tee ./flattens/PrizeReservePool_flatten.sol
# npx hardhat flatten ./contracts/RandomNumberGenerator.sol 2>&1 | tee ./flattens/RandomNumberGenerator_flatten.sol
# npx hardhat flatten ./contracts/TaxService.sol 2>&1 | tee ./flattens/TaxService_flatten.sol
# npx hardhat flatten ./contracts/Ticket.sol 2>&1 | tee ./flattens/Ticket_flatten.sol
npx hardhat flatten ./contracts/Zap.sol 2>&1 | tee ./flattens/Zap_flatten.sol
