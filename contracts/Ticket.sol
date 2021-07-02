//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/ILottery.sol";

contract Ticket is ERC1155, Ownable {
    // Libraries

    // State variables
    address internal lotteryContract_;

    uint256 internal totalSupply_;

    // Storage for ticket information
    struct TicketInfo {
        address owner;
        uint16[] numbers;
        bool claimed;
        uint256 lotteryId;
    }
    // Token ID => Token information
    mapping(uint256 => TicketInfo) internal ticketInfo_;
    // lottery ID => tickets count
    mapping(uint256 => uint256) internal ticketsCount_;
    // User address => Lottery ID => Ticket IDs
    mapping(address => mapping(uint256 => uint256[])) internal userTickets_;

    // These stated is fixed due to technical implementation
    // Lottery size, power number not included
    uint8 public constant sizeOfLottery_ = 4;
    // support 2 numbers match, if require 3 numbers match, use value of 5
    // uint8 public constant sizeOfIndex_ = 5;
    // lotteryId => hash => count
    // the hash is combined from ticked numbers
    mapping(uint256 => mapping(uint256 => uint256)) internal ticketHashes_;

    //-------------------------------------------------------------------------
    // EVENTS
    //-------------------------------------------------------------------------

    event InfoBatchMint(address indexed receiving, uint256 lotteryId, uint256 amountOfTokens, uint256[] tokenIds);

    //-------------------------------------------------------------------------
    // MODIFIERS
    //-------------------------------------------------------------------------

    /**
     * @notice  Restricts minting of new tokens to only the lotto contract.
     */
    modifier onlyLotto() {
        require(msg.sender == lotteryContract_, "Only Lotto can mint");
        _;
    }

    //-------------------------------------------------------------------------
    // CONSTRUCTOR
    //-------------------------------------------------------------------------

    /**
     * @param   _uri A dynamic URI that enables individuals to view information
     *          around their NFT token. To see the information replace the
     *          `\{id\}` substring with the actual token type ID. For more info
     *          visit:
     *          https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     * @param   _lotto The address of the lotto contract. The lotto contract has
     *          elevated permissions on this contract.
     */
    constructor(string memory _uri, address _lotto) ERC1155(_uri) {
        // Only Lotto contract will be able to mint new tokens
        lotteryContract_ = _lotto;
    }

    //-------------------------------------------------------------------------
    // VIEW FUNCTIONS
    //-------------------------------------------------------------------------

    function getTotalSupply() external view returns (uint256) {
        return totalSupply_;
    }

    /**
     * @param   _ticketID: The unique ID of the ticket
     * @return  uint32[]: The chosen numbers for that ticket
     */
    function getTicketNumbers(uint256 _ticketID) external view returns (uint16[] memory) {
        return ticketInfo_[_ticketID].numbers;
    }

    /**
     * @param   _ticketID: The unique ID of the ticket
     * @return  address: Owner of ticket
     */
    function getOwnerOfTicket(uint256 _ticketID) external view returns (address) {
        return ticketInfo_[_ticketID].owner;
    }

    function getTicketClaimStatus(uint256 _ticketID) external view returns (bool) {
        return ticketInfo_[_ticketID].claimed;
    }

    function getTicketClaimStatuses(uint256[] calldata ticketIds) external view returns (bool[] memory ticketStatuses) {
        ticketStatuses = new bool[](ticketIds.length);
        for (uint256 i = 0; i < ticketIds.length; i++) {
            ticketStatuses[i] = ticketInfo_[ticketIds[i]].claimed;
        }
    }

    function getUserTickets(uint256 _lotteryId, address _user) external view returns (uint256[] memory) {
        return userTickets_[_user][_lotteryId];
    }

    function getListTicketNumbers(uint256[] calldata ticketIds)
        external
        view
        returns (uint256[] memory ticketNumbers, uint256 sizeOfLottery)
    {
        sizeOfLottery = sizeOfLottery_ + 1;
        ticketNumbers = new uint256[](ticketIds.length * sizeOfLottery);
        for (uint256 i = 0; i < ticketIds.length; i++) {
            uint16[] memory ticketNumber = ticketInfo_[ticketIds[i]].numbers;
            if (ticketNumber.length != sizeOfLottery) {
                ticketNumber = new uint16[](sizeOfLottery);
            }
            for (uint256 j = 0; j < ticketNumber.length; j++) {
                ticketNumbers[sizeOfLottery * i + j] = ticketNumber[j];
            }
        }
    }

    function getNumberOfTickets(uint256 _lotteryId) external view returns (uint256) {
        return ticketsCount_[_lotteryId];
    }

    function getUserTicketsPagination(
        address _user,
        uint256 _lotteryId,
        uint256 cursor,
        uint256 size
    ) external view returns (uint256[] memory, uint256) {
        uint256 length = size;
        if (length > userTickets_[_user][_lotteryId].length - cursor) {
            length = userTickets_[_user][_lotteryId].length - cursor;
        }
        uint256[] memory values = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = userTickets_[_user][_lotteryId][cursor + i];
        }
        return (values, cursor + length);
    }

    //-------------------------------------------------------------------------
    // STATE MODIFYING FUNCTIONS
    //-------------------------------------------------------------------------

    /**
     * @param   _to The address being minted to
     * @param   _numberOfTickets The number of NFT's to mint
     * @notice  Only the lotto contract is able to mint tokens.
        // uint8[][] calldata _lottoNumbers
     */
    function batchMint(
        address _to,
        uint256 _lotteryId,
        uint8 _numberOfTickets,
        uint16 _maxValidRange,
        uint16[] calldata _numbers
    ) external onlyLotto() returns (uint256[] memory) {
        // Storage for the amount of tokens to mint (always 1)
        uint256[] memory amounts = new uint256[](_numberOfTickets);
        // Storage for the token IDs
        uint256[] memory tokenIds = new uint256[](_numberOfTickets);
        for (uint8 i = 0; i < _numberOfTickets; i++) {
            // Incrementing the tokenId counter
            totalSupply_ = totalSupply_ + 1;
            tokenIds[i] = totalSupply_;
            amounts[i] = 1;
            // Getting the start and end position of numbers for this ticket
            uint16 start = uint16(i * (sizeOfLottery_ + 1));
            uint16 end = uint16((i + 1) * (sizeOfLottery_ + 1));
            // Splitting out the chosen numbers
            uint16[] calldata numbers = _numbers[start:end];
            // Storing the ticket information
            ticketInfo_[totalSupply_] = TicketInfo(_to, numbers, false, _lotteryId);
            userTickets_[_to][_lotteryId].push(totalSupply_);
            indexTicket(_lotteryId, _maxValidRange, numbers);
        }
        // Minting the batch of tokens
        _mintBatch(_to, tokenIds, amounts, msg.data);
        ticketsCount_[_lotteryId] = ticketsCount_[_lotteryId] + _numberOfTickets;
        // Emitting relevant info
        emit InfoBatchMint(_to, _lotteryId, _numberOfTickets, tokenIds);
        // Returns the token IDs of minted tokens
        return tokenIds;
    }

    function indexTicket(
        uint256 _lotteryId,
        uint16 _maxValidRange,
        uint16[] memory _numbers
    ) internal {
        uint256[2] memory indexes = generateNumberIndexKey(_maxValidRange, _numbers);
        for (uint256 j = 0; j < indexes.length; j++) {
            ticketHashes_[_lotteryId][indexes[j]]++;
        }
    }

    function claimTicket(uint256 _ticketID, uint256 _lotteryId) external onlyLotto() returns (bool) {
        require(ticketInfo_[_ticketID].claimed == false, "Ticket already claimed");
        require(ticketInfo_[_ticketID].lotteryId == _lotteryId, "Ticket not for this lottery");
        uint256 maxRange = ILottery(lotteryContract_).getMaxRange();
        for (uint256 i = 0; i < ticketInfo_[_ticketID].numbers.length; i++) {
            if (ticketInfo_[_ticketID].numbers[i] > maxRange) {
                return false;
            }
        }

        ticketInfo_[_ticketID].claimed = true;
        return true;
    }

    function setLottery(address _lottery) external onlyOwner {
        require(_lottery != address(0), "Invalid address");
        lotteryContract_ = _lottery;
    }

    //-------------------------------------------------------------------------
    // INTERNAL FUNCTIONS
    //-------------------------------------------------------------------------

    /**
     * calculate the index for matching
     * eg: 0x0102030402 <- mean ticket 01 02 03 04 missing 2 numbers
     * eg: 0x0102030400 <- mean ticket 01 02 03 04 missing 0 numbers
     * the last element is Jackpot index.
     * eg: ticket 01 02 03 04 21 has index: 0x010203040021
     */
    function generateNumberIndexKey(uint16 _maxValidRange, uint16[] memory numbers)
        public
        pure
        returns (uint256[2] memory result)
    {
        uint16 power = numbers[numbers.length - 1];
        uint256 len = numbers.length - 1;
        uint256 key;
        for (uint256 index = 0; index < len; index++) {
            key += 1 << (numbers[index] - 1);
        }

        result[0] = key;
        result[1] = key + (1 << _maxValidRange) * power;
    }

    function countMatch(
        uint256 _lotteryId,
        uint16 _maxValidRange,
        uint16[] calldata _winningNumbers
    ) external view returns (uint256[] memory results) {
        results = new uint256[](sizeOfLottery_ + 1);
        uint256[2] memory keys = generateNumberIndexKey(_maxValidRange, _winningNumbers);
        uint256 match4Key = keys[0];
        uint256 jackpotKey = keys[1];
        results[0] = ticketHashes_[_lotteryId][jackpotKey];
        results[1] = ticketHashes_[_lotteryId][match4Key] - results[0];

        // count match 3 numbers
        // remove each number and replace with others
        uint256 key;
        for (uint256 i = 0; i < sizeOfLottery_; i++) {
            uint256 base = match4Key - (1 << (_winningNumbers[i] - 1));
            for (uint256 j = 1; j < _maxValidRange + 1; j++) {
                if (j == _winningNumbers[i]) {
                    continue;
                }
                key = 1 << (j - 1);

                if ((key & base) == 0) {
                    results[2] += ticketHashes_[_lotteryId][base + key];
                }
            }
        }
    }
}
