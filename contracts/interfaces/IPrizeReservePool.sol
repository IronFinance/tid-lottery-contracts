// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IPrizeReservePool {
    /**
     * Funding a minimal amount when prize pool is empty
     * @param amount amount of IRON to be set as prize
     */
    function fund(uint256 amount) external;
}
