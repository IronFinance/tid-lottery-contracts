// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IPrizeReservePool.sol";
import "./interfaces/IERC20Burnable.sol";

contract PrizeReservePool is Ownable {
    using SafeERC20 for IERC20Burnable;
    IERC20Burnable public titan_;
    address public lottery_;

    constructor(address _titan, address _lottery) {
        require(_titan != address(0), "!address");
        require(_lottery != address(0), "!address");
        titan_ = IERC20Burnable(_titan);
        lottery_ = _lottery;
    }

    modifier onlyLottery() {
        require(address(msg.sender) == lottery_, "Caller is not the lottery");
        _;
    }

    function setLottery(address _lottery) external onlyOwner {
        lottery_ = _lottery;
    }

    function balance() external view returns (uint256) {
        return titan_.balanceOf(address(this));
    }

    function fund(uint256 amount) external onlyLottery {
        titan_.safeTransfer(lottery_, amount);
    }

    function burn(uint256 amount) external onlyOwner {
        titan_.burn(amount);
    }
}
