//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface ILottery {
    //-------------------------------------------------------------------------
    // VIEW FUNCTIONS
    //-------------------------------------------------------------------------

    function getMaxRange() external view returns (uint32);

    //-------------------------------------------------------------------------
    // STATE MODIFYING FUNCTIONS
    //-------------------------------------------------------------------------

    function numbersDrawn(
        uint256 _lotteryId,
        bytes32 _requestId,
        uint256 _randomNumber
    ) external;

    function costToBuyTickets(uint256 _lotteryId, uint256 _numberOfTickets) external view returns (uint256 totalCost);
}
