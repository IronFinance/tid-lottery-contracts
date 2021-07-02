//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRandomNumberGenerator.sol";
import "./interfaces/ITicket.sol";
import "./utils/Testable.sol";
import "./interfaces/ITaxService.sol";
import "./interfaces/IPrizeReservePool.sol";

contract Lottery is Ownable, Initializable, Testable {
    // using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    // Represents the status of the lottery
    enum Status {
        NotStarted, // The lottery has not started yet
        Open, // The lottery is open for ticket purchases
        Closed, // The lottery is no longer open for ticket purchases
        Completed // The numbers drawn
    }

    // All the needed info around a lottery
    struct LottoInfo {
        uint256 lotteryID; // ID for lotto
        Status lotteryStatus; // Status for lotto
        uint256 prizePool; // The amount of TITAN for prize money
        uint256 costPerTicket; // Cost per ticket in $TITAN
        uint256[] prizeDistribution; // The distribution for prize money
        uint256 startingTimestamp; // Block timestamp for star of lotto
        uint256 closingTimestamp; // Block timestamp for end of entries
        uint16[] winningNumbers; // The winning numbers
        uint256[] winners; // the winners of each prize
    }

    // State variables
    // Instance of TITAN token (collateral currency for lotto)
    IERC20 internal titan_;
    // Storing of the NFT
    ITicket internal ticket_;

    // Random number generator
    // Storing of the randomness generator
    IRandomNumberGenerator internal randomGenerator_;
    // Instance of TaxCollection
    ITaxService internal taxService_;
    // Request ID for random number
    bytes32 internal requestId_;

    // Counter for lottery IDs
    uint256 private lotteryIdCounter_;

    // These stated is fixed due to technical implementation
    // Lottery size, power number not included
    uint8 public constant sizeOfLottery_ = 4;
    // support 2 numbers match, if require 3 numbers match, use value of 5
    // uint8 public constant sizeOfIndex_ = 5;

    // precision for all distribution
    uint256 public constant PRECISION = 1e6;
    uint256 public unclaimedPrize_;
    address public controller_;
    address public zap_;

    // Max range for numbers (starting at 0)
    uint16 public maxValidRange_;
    uint16 public powerBallRange_;

    // settings for lotto, will be applied to newly created lotto
    uint256 public startingPrize_;
    uint256 public costPerTicket_; // Cost per ticket in $TITAN

    // The distribution for prize money, highest first
    uint256[] public prizeDistribution_;

    uint256 public taxRate_;
    address public prizeReservePool_;

    // Lottery ID's to info
    mapping(uint256 => LottoInfo) internal allLotteries_;

    bool public upgraded_ = false;

    //-------------------------------------------------------------------------
    // EVENTS
    //-------------------------------------------------------------------------

    event NewBatchMint(address indexed minter, uint256[] ticketIDs, uint16[] numbers, uint256 pricePaid);

    event RequestNumbers(uint256 lotteryId, bytes32 requestId);

    event LotterySettingsUpdated(
        uint16 maxValidRange,
        uint16 powerBallRange,
        uint256[] prizeDistribution,
        uint256 startingPrize,
        uint256 costPerTicket
    );

    event LotteryOpened(uint256 lotteryId, uint256 ticketSupply);

    event LotteryClosed(uint256 lotteryId, uint256 ticketSupply);

    event WinnersDrawn(uint256[] numbers);

    //-------------------------------------------------------------------------
    // MODIFIERS
    //-------------------------------------------------------------------------

    modifier onlyRandomGenerator() {
        require(msg.sender == address(randomGenerator_), "Only random generator");
        _;
    }

    modifier onlyController() {
        require(msg.sender == controller_, "Only controller");
        _;
    }

    modifier notContract() {
        require(!address(msg.sender).isContract(), "contract not allowed");
        // solhint-disable-next-line avoid-tx-origin
        require(msg.sender == tx.origin, "proxy contract not allowed");
        _;
    }

    modifier notUpgraded() {
        require(upgraded_ == false, "This contract was upgraded");
        _;
    }

    //-------------------------------------------------------------------------
    // CONSTRUCTOR
    //-------------------------------------------------------------------------

    // solhint-disable-next-line no-empty-blocks
    constructor(address _timer) Testable(_timer) {}

    function initialize(
        address _titan,
        address _ticket,
        address _randomNumberGenerator,
        address _prizeReservePool,
        address _taxService,
        address _controller
    ) external initializer onlyOwner {
        require(
            _ticket != address(0) &&
                _randomNumberGenerator != address(0) &&
                _prizeReservePool != address(0) &&
                _taxService != address(0) &&
                _titan != address(0),
            "Contracts cannot be 0 address"
        );
        titan_ = IERC20(_titan);
        ticket_ = ITicket(_ticket);
        randomGenerator_ = IRandomNumberGenerator(_randomNumberGenerator);
        prizeReservePool_ = _prizeReservePool;
        taxService_ = ITaxService(_taxService);
        controller_ = _controller;
    }

    //-------------------------------------------------------------------------
    // VIEW FUNCTIONS
    //-------------------------------------------------------------------------

    function costToBuyTickets(uint256 _lotteryId, uint256 _numberOfTickets) external view returns (uint256 totalCost) {
        uint256 pricePer = allLotteries_[_lotteryId].costPerTicket;
        totalCost = pricePer * _numberOfTickets; // solidity 0.8 auto handle overflow
    }

    function getBasicLottoInfo(uint256 _lotteryId) external view returns (LottoInfo memory) {
        return (allLotteries_[_lotteryId]);
    }

    function getCurrentLotto() external view returns (LottoInfo memory) {
        require(lotteryIdCounter_ > 0, "no lottery created");
        return allLotteries_[lotteryIdCounter_];
    }

    function getCurrentTotalPrize() public view returns (uint256 totalPrize) {
        totalPrize = titan_.balanceOf(address(this)) - unclaimedPrize_;
    }

    function getMaxRange() external view returns (uint16) {
        return maxValidRange_;
    }

    function getCurrentPrizes() public view returns (uint256[] memory prizes) {
        require(lotteryIdCounter_ > 0, "no lottery created");
        LottoInfo storage lotto = allLotteries_[lotteryIdCounter_];
        prizes = new uint256[](lotto.prizeDistribution.length);

        uint256 totalPrize = getCurrentTotalPrize();
        for (uint256 i = 0; i < lotto.prizeDistribution.length; i++) {
            prizes[i] = (totalPrize * lotto.prizeDistribution[i]) / PRECISION;
        }
    }

    //-------------------------------------------------------------------------
    // Restricted Access Functions (onlyOwner)

    /**
     * manually start by admin, by pass auto duration
     */
    function manualStartLotto(uint256 _startingTime, uint256 _closingTime) external onlyController returns (uint256) {
        return _createNewLotto(_startingTime, _closingTime);
    }

    function manuallyOpenLotto() external onlyController {
        require(lotteryIdCounter_ > 0, "no lottery created");
        LottoInfo storage _currLotto = allLotteries_[lotteryIdCounter_];
        uint256 currentTime = getCurrentTime();
        require(currentTime >= _currLotto.startingTimestamp, "Invalid time for mint:start");
        require(currentTime < _currLotto.closingTimestamp, "Invalid time for mint:end");
        if (_currLotto.lotteryStatus == Status.NotStarted) {
            if (_currLotto.startingTimestamp <= getCurrentTime()) {
                _currLotto.lotteryStatus = Status.Open;
            }
        }
    }

    function setTaxRate(uint256 _taxRate) external onlyOwner {
        require(_taxRate <= PRECISION, "total must lower than 100%");
        taxRate_ = _taxRate;
    }

    function setController(address _controller) external onlyOwner {
        require(_controller != address(0), "Contracts cannot be 0 address");
        controller_ = _controller;
    }

    function setPrizeReservePool(address _prizeReservePool) external onlyOwner {
        require(_prizeReservePool != address(0), "Contracts cannot be 0 address");
        prizeReservePool_ = _prizeReservePool;
    }

    function setTaxService(address _taxService) external onlyOwner {
        require(_taxService != address(0), "Contracts cannot be 0 address");
        taxService_ = ITaxService(_taxService);
    }

    function setRandomGenerator(address _randomGenerator) external onlyOwner {
        require(_randomGenerator != address(0), "Contracts cannot be 0 address");
        randomGenerator_ = IRandomNumberGenerator(_randomGenerator);
    }

    function setTicket(address _ticket) external onlyOwner {
        require(_ticket != address(0), "Contracts cannot be 0 address");
        ticket_ = ITicket(_ticket);
    }

    function withdrawFund(address receiver) external onlyOwner {
        require(receiver != address(0), "Invalid address");
        uint256 _movableAmount = getCurrentTotalPrize();
        upgraded_ = true;
        titan_.safeTransfer(receiver, _movableAmount);
    }

    /**
     * @param   _prizeDistribution An array defining the distribution of the
     *          prize pool. I.e if a lotto has 5 numbers, the distribution could
     *          be [5, 10, 15, 20, 30] = 100%. This means if you get one number
     *          right you get 5% of the pool, 2 matching would be 10% and so on.
     */
    function updateLottoSettings(
        uint16 _maxValidRange,
        uint16 _powerBallRange,
        uint256[] calldata _prizeDistribution,
        uint256 _costPerTicket,
        uint256 _startingPrize
    ) external onlyOwner {
        require(_maxValidRange >= 4, "Range of number must be 4 atleast");
        require(_powerBallRange != 0, "Power number range can not be 0");
        require(_startingPrize != 0 && _costPerTicket != 0, "Prize or cost cannot be 0");
        // Ensuring that prize distribution total is 100%
        uint256 prizeDistributionTotal = 0;
        for (uint256 j = 0; j < _prizeDistribution.length; j++) {
            prizeDistributionTotal = prizeDistributionTotal + uint256(_prizeDistribution[j]);
        }
        require(prizeDistributionTotal == PRECISION, "Prize distribution is not 100%");

        maxValidRange_ = _maxValidRange;
        powerBallRange_ = _powerBallRange;
        prizeDistribution_ = _prizeDistribution;
        startingPrize_ = _startingPrize;
        costPerTicket_ = _costPerTicket;

        emit LotterySettingsUpdated(
            maxValidRange_,
            powerBallRange_,
            prizeDistribution_,
            startingPrize_,
            costPerTicket_
        );
    }

    function drawWinningNumbers(uint256 _lotteryId) external onlyController notUpgraded {
        LottoInfo storage _currLotto = allLotteries_[_lotteryId];
        // Checks that the lottery is past the closing block
        require(_currLotto.closingTimestamp <= getCurrentTime(), "Cannot set winning numbers during lottery");
        // Checks lottery numbers have not already been drawn
        require(_currLotto.lotteryStatus == Status.Open, "Lottery State incorrect for draw");
        // Sets lottery status to closed
        _currLotto.lotteryStatus = Status.Closed;
        // Sets prize pool
        _currLotto.prizePool = getCurrentTotalPrize();
        // Requests a random number from the generator
        requestId_ = randomGenerator_.getRandomNumber(_lotteryId);
        // Emits that random number has been requested
        emit RequestNumbers(_lotteryId, requestId_);
    }

    function retryDrawWinningNumbers(uint256 _lotteryId) external onlyController notUpgraded {
        LottoInfo storage _currLotto = allLotteries_[_lotteryId];
        require(_currLotto.closingTimestamp <= getCurrentTime(), "Cannot set winning numbers during lottery");
        require(_currLotto.lotteryStatus == Status.Closed, "Lottery State incorrect for retry");
        requestId_ = randomGenerator_.getRandomNumber(_lotteryId);
        emit RequestNumbers(_lotteryId, requestId_);
    }

    function numbersDrawn(
        uint256 _lotteryId,
        bytes32 _requestId,
        uint256 _randomNumber
    ) external onlyRandomGenerator() notUpgraded {
        LottoInfo storage _currLotto = allLotteries_[_lotteryId];
        require(_currLotto.lotteryStatus == Status.Closed, "Draw numbers first");
        if (requestId_ == _requestId) {
            _currLotto.winningNumbers = _split(_randomNumber);
            uint256[] memory matches = ticket_.countMatch(_lotteryId, maxValidRange_, _currLotto.winningNumbers);
            _currLotto.lotteryStatus = Status.Completed;
            uint256 _actualPrizeDistribution = 0;
            for (uint256 i = 0; i < _currLotto.prizeDistribution.length; i++) {
                _currLotto.winners[i] = matches[i];
                if (matches[i] > 0) {
                    _actualPrizeDistribution = _actualPrizeDistribution + _currLotto.prizeDistribution[i];
                }
            }
            uint256 _totalPrize = (getCurrentTotalPrize() * _actualPrizeDistribution) / PRECISION;
            if (_totalPrize > 0) {
                uint256 _taxAmount = (_totalPrize * taxRate_) / PRECISION;
                uint256 _prizeAfterTax = _totalPrize - _taxAmount;
                _addUnclaimedPrize(_prizeAfterTax);
                _collectTax(_taxAmount);
            }
        }

        emit LotteryClosed(_lotteryId, ticket_.getTotalSupply());
    }

    //-------------------------------------------------------------------------
    // General Access Functions

    function batchBuyLottoTicket(
        uint256 _lotteryId,
        uint8 _numberOfTickets,
        uint16[] calldata _chosenNumbersForEachTicket
    ) external notContract() notUpgraded {
        // Ensuring the lottery is within a valid time
        uint256 currentTime = getCurrentTime();
        LottoInfo storage _currLotto = allLotteries_[_lotteryId];
        require(currentTime >= _currLotto.startingTimestamp, "Invalid time for mint:start");
        require(currentTime < _currLotto.closingTimestamp, "Invalid time for mint:end");

        if (_currLotto.lotteryStatus == Status.NotStarted) {
            if (_currLotto.startingTimestamp <= getCurrentTime()) {
                _currLotto.lotteryStatus = Status.Open;
            }
        }

        require(_currLotto.lotteryStatus == Status.Open, "Lottery not in state for mint");
        validateTicketNumbers(_numberOfTickets, _chosenNumbersForEachTicket);
        uint256 totalCost = this.costToBuyTickets(_lotteryId, _numberOfTickets);

        // Batch mints the user their tickets
        uint256[] memory ticketIds = ticket_.batchMint(
            msg.sender,
            _lotteryId,
            _numberOfTickets,
            maxValidRange_,
            _chosenNumbersForEachTicket
        );

        // Emitting event with all information
        emit NewBatchMint(msg.sender, ticketIds, _chosenNumbersForEachTicket, totalCost);

        // Transfers the required titan to this contract
        titan_.safeTransferFrom(msg.sender, address(this), totalCost);
    }

    function claimReward(uint256 _lotteryId, uint256 _tokenId) external notContract() {
        // Checking the lottery is in a valid time for claiming
        require(allLotteries_[_lotteryId].closingTimestamp <= getCurrentTime(), "Wait till end to claim");
        // Checks the lottery winning numbers are available
        require(allLotteries_[_lotteryId].lotteryStatus == Status.Completed, "Winning Numbers not chosen yet");
        require(ticket_.getOwnerOfTicket(_tokenId) == msg.sender, "Only the owner can claim");
        // Sets the claim of the ticket to true (if claimed, will revert)
        require(ticket_.claimTicket(_tokenId, _lotteryId), "Numbers for ticket invalid");
        // Getting the number of matching tickets
        uint8 matchingNumbers = _getNumberOfMatching(
            ticket_.getTicketNumbers(_tokenId),
            allLotteries_[_lotteryId].winningNumbers
        );
        // Getting the prize amount for those matching tickets
        uint256 prizeAmount = _prizeForMatching(matchingNumbers, _lotteryId);
        // Transfering the user their winnings
        _claimPrize(msg.sender, prizeAmount);
    }

    function batchClaimRewards(uint256 _lotteryId, uint256[] calldata _tokeIds) external notContract() {
        require(_tokeIds.length <= 50, "Batch claim too large");
        // Checking the lottery is in a valid time for claiming
        require(allLotteries_[_lotteryId].closingTimestamp <= getCurrentTime(), "Wait till end to claim");
        // Checks the lottery winning numbers are available
        require(allLotteries_[_lotteryId].lotteryStatus == Status.Completed, "Winning Numbers not chosen yet");
        // Creates a storage for all winnings
        uint256 totalPrize = 0;
        // Loops through each submitted token
        for (uint256 i = 0; i < _tokeIds.length; i++) {
            // Checks user is owner (will revert entire call if not)
            require(ticket_.getOwnerOfTicket(_tokeIds[i]) == msg.sender, "Only the owner can claim");
            // If token has already been claimed, skip token
            if (ticket_.getTicketClaimStatus(_tokeIds[i])) {
                continue;
            }
            // Claims the ticket (will only revert if numbers invalid)
            require(ticket_.claimTicket(_tokeIds[i], _lotteryId), "Numbers for ticket invalid");
            // Getting the number of matching tickets
            uint8 matchingNumbers = _getNumberOfMatching(
                ticket_.getTicketNumbers(_tokeIds[i]),
                allLotteries_[_lotteryId].winningNumbers
            );
            // Getting the prize amount for those matching tickets
            uint256 prizeAmount = _prizeForMatching(matchingNumbers, _lotteryId);
            totalPrize = totalPrize + prizeAmount;
        }
        // Transferring the user their winnings
        _claimPrize(msg.sender, totalPrize);
    }

    //-------------------------------------------------------------------------
    // INTERNAL FUNCTIONS
    //-------------------------------------------------------------------------
    /**
     * @param   _startingTimestamp The block timestamp for the beginning of the
     *          lottery.
     * @param   _closingTimestamp The block timestamp after which no more tickets
     *          will be sold for the lottery. Note that this timestamp MUST
     *          be after the starting block timestamp.
     */
    function _createNewLotto(uint256 _startingTimestamp, uint256 _closingTimestamp)
        internal
        notUpgraded
        returns (uint256 lotteryId)
    {
        require(_startingTimestamp != 0 && _startingTimestamp < _closingTimestamp, "Timestamps for lottery invalid");
        require(
            lotteryIdCounter_ == 0 || allLotteries_[lotteryIdCounter_].lotteryStatus == Status.Completed,
            "current lottery is not completed"
        );
        // Incrementing lottery ID
        lotteryIdCounter_ = lotteryIdCounter_ + 1;
        lotteryId = lotteryIdCounter_;
        uint16[] memory winningNumbers = new uint16[](sizeOfLottery_ + 1);
        uint256[] memory winnersCount = new uint256[](prizeDistribution_.length);
        Status lotteryStatus;
        if (_startingTimestamp > getCurrentTime()) {
            lotteryStatus = Status.NotStarted;
        } else {
            lotteryStatus = Status.Open;
        }

        //transfer from reserve pool to poolPrize if current < minPrize
        if (getCurrentTotalPrize() < startingPrize_) {
            IPrizeReservePool(prizeReservePool_).fund(startingPrize_ - getCurrentTotalPrize());
        }

        // Saving data in struct
        LottoInfo memory newLottery = LottoInfo(
            lotteryId,
            lotteryStatus,
            startingPrize_,
            costPerTicket_,
            prizeDistribution_,
            _startingTimestamp,
            _closingTimestamp,
            winningNumbers,
            winnersCount
        );
        allLotteries_[lotteryId] = newLottery;

        // Emitting important information around new lottery.
        emit LotteryOpened(lotteryId, ticket_.getTotalSupply());
    }

    function _getNumberOfMatching(uint16[] memory _usersNumbers, uint16[] memory _winningNumbers)
        internal
        pure
        returns (uint8 noOfMatching)
    {
        // Loops through all winning numbers
        for (uint256 i = 0; i < _winningNumbers.length - 1; i++) {
            for (uint256 j = 0; j < _usersNumbers.length - 1; j++) {
                // If the winning numbers and user numbers match
                if (_usersNumbers[i] == _winningNumbers[j]) {
                    // The number of matching numbers increases
                    noOfMatching += 1;
                }
            }
        }

        // compare power number
        if (
            noOfMatching == sizeOfLottery_ &&
            _winningNumbers[_winningNumbers.length - 1] == _usersNumbers[_usersNumbers.length - 1]
        ) {
            noOfMatching += 1;
        }
    }

    function _claimPrize(address _winner, uint256 _amount) internal {
        unclaimedPrize_ = unclaimedPrize_ - _amount;
        titan_.safeTransfer(_winner, _amount);
    }

    function _addUnclaimedPrize(uint256 amount) internal {
        unclaimedPrize_ = unclaimedPrize_ + amount;
    }

    function _collectTax(uint256 _taxAmount) internal {
        titan_.safeApprove(address(taxService_), 0);
        titan_.safeApprove(address(taxService_), _taxAmount);
        taxService_.collect(_taxAmount);
    }

    /**
     * @param   _noOfMatching: The number of matching numbers the user has
     * @param   _lotteryId: The ID of the lottery the user is claiming on
     * @return  prize  The prize amount in cake the user is entitled to
     */
    function _prizeForMatching(uint8 _noOfMatching, uint256 _lotteryId) public view returns (uint256 prize) {
        prize = 0;
        if (_noOfMatching > 0) {
            // Getting the percentage of the pool the user has won
            uint256 prizeIndex = sizeOfLottery_ + 1 - _noOfMatching;
            uint256 perOfPool = allLotteries_[_lotteryId].prizeDistribution[prizeIndex];
            uint256 numberOfWinners = allLotteries_[_lotteryId].winners[prizeIndex];

            if (numberOfWinners > 0) {
                prize =
                    (allLotteries_[_lotteryId].prizePool * perOfPool * (PRECISION - taxRate_)) /
                    numberOfWinners /
                    (PRECISION**2);
            }
        }
    }

    function _split(uint256 _randomNumber) internal view returns (uint16[] memory) {
        uint16[] memory winningNumbers = new uint16[](sizeOfLottery_ + 1);

        uint16[] memory array = new uint16[](maxValidRange_);
        for (uint16 i = 0; i < maxValidRange_; i++) {
            array[i] = i + 1;
        }

        uint16 temp;

        for (uint256 i = array.length - 1; i > 0; i--) {
            uint256 j = uint256(keccak256(abi.encodePacked(_randomNumber, i))) % i;
            temp = array[i];
            array[i] = array[j];
            array[j] = temp;
        }

        for (uint256 i = 0; i < sizeOfLottery_; i++) {
            winningNumbers[i] = array[i];
        }

        winningNumbers[sizeOfLottery_] = (uint16(_randomNumber) % powerBallRange_) + 1;
        return winningNumbers;
    }

    function validateTicketNumbers(uint8 _numberOfTickets, uint16[] memory _numbers) internal view {
        require(_numberOfTickets <= 50, "Batch mint too large");
        require(_numbers.length == _numberOfTickets * (sizeOfLottery_ + 1), "Invalid chosen numbers");

        for (uint256 i = 0; i < _numbers.length; i++) {
            uint256 k = i % (sizeOfLottery_ + 1);
            if (k == sizeOfLottery_) {
                require(_numbers[i] > 0 && _numbers[i] <= powerBallRange_, "out of range: power number");
            } else {
                require(_numbers[i] > 0 && _numbers[i] <= maxValidRange_, "out of range: number");
            }
            if (k > 0 && k != sizeOfLottery_) {
                for (uint256 j = i - k; j <= i - 1; j++) {
                    require(_numbers[i] != _numbers[j], "duplicate number");
                }
            }
        }
    }
}
