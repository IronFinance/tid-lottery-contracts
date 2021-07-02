//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/ITaxService.sol";
import "./interfaces/IERC20Burnable.sol";

contract TaxService is Ownable, ITaxService, Initializable {
    using SafeERC20 for IERC20Burnable;

    address public titan_;
    address public lottery_;
    address public prizeReservePool_;

    uint256 public reservePoolRatio_ = 300000; // 30%
    uint256 public burnTitanPoolRatio_ = 700000; // 70%

    uint256 private constant PRECISION = 1e6;

    function initialize(
        address _titan,
        address _lottery,
        address _prizeReservePool
    ) external initializer onlyOwner() {
        require(
            _titan != address(0) && _lottery != address(0) && _prizeReservePool != address(0),
            "Contracts cannot be 0 address"
        );
        titan_ = _titan;
        lottery_ = _lottery;
        prizeReservePool_ = _prizeReservePool;
    }

    //-------------------------------------------------------------------------
    // MODIFIERS
    //-------------------------------------------------------------------------

    /**
     * @notice  Restricts to only the lottery contract.
     */
    modifier onlyLottery() {
        require(address(msg.sender) == lottery_, "Caller is not the lottery");
        _;
    }

    //==============================
    // STATE MODIFYING FUNCTIONS
    //==============================

    function setPrizeReservePool(address _prizeReservePool) external onlyOwner {
        require(_prizeReservePool != address(0), "Contracts cannot be 0 address");
        prizeReservePool_ = _prizeReservePool;
    }

    function setLottery(address _lottery) external onlyOwner {
        lottery_ = _lottery;
    }

    function setDistribution(uint256 _reservePoolRatio, uint256 _burnTitanPoolRatio) external onlyOwner {
        reservePoolRatio_ = _reservePoolRatio;
        burnTitanPoolRatio_ = _burnTitanPoolRatio;
    }

    function collect(uint256 amount) external override onlyLottery {
        uint256 _totalRatio = burnTitanPoolRatio_ + reservePoolRatio_;
        uint256 _burnTitanAmount = (amount * burnTitanPoolRatio_) / _totalRatio;
        uint256 _prizeReserve = amount - _burnTitanAmount;

        IERC20Burnable _titan = IERC20Burnable(titan_);
        _titan.safeTransferFrom(lottery_, address(this), amount);

        if (_prizeReserve > 0) {
            _titan.safeTransfer(prizeReservePool_, _prizeReserve);
        }

        if (_burnTitanAmount > 0) {
            _titan.burn(_burnTitanAmount);
        }
    }
}
