//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
pragma experimental ABIEncoderV2;

interface ITicket {
    //-------------------------------------------------------------------------
    // VIEW FUNCTIONS
    //-------------------------------------------------------------------------

    function getTotalSupply() external view returns (uint256);

    function getTicketNumbers(uint256 _ticketID) external view returns (uint16[] memory);

    function getOwnerOfTicket(uint256 _ticketID) external view returns (address);

    function getTicketClaimStatus(uint256 _ticketID) external view returns (bool);

    //-------------------------------------------------------------------------
    // STATE MODIFYING FUNCTIONS
    //-------------------------------------------------------------------------

    function batchMint(
        address _to,
        uint256 _lottoID,
        uint8 _numberOfTickets,
        uint16 _maxValidRange,
        uint16[] calldata _numbers
    ) external returns (uint256[] memory);

    function claimTicket(uint256 _ticketId, uint256 _lotteryId) external returns (bool);

    function countMatch(
        uint256 _lotteryId,
        uint16 _maxValidRange,
        uint16[] calldata _winningNumbers
    ) external view returns (uint256[] memory results);
}
