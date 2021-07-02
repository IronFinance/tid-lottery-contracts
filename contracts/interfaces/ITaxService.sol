//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface ITaxService {
    /**
     * collect iron
     * @param amount amount of IRON
     */
    function collect(uint256 amount) external;
}
