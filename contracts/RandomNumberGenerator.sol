//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@chainlink/contracts/src/v0.8/dev/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ILottery.sol";

contract RandomNumberGenerator is VRFConsumerBase, Ownable {
    bytes32 internal keyHash;
    uint256 internal fee;
    address internal requester;
    uint256 public randomResult;
    uint256 public currentLotteryId;

    address public lottery;

    modifier onlyLottery() {
        require(msg.sender == lottery, "Only Lottery can call function");
        _;
    }

    constructor(
        address _vrfCoordinator,
        address _linkToken,
        address _lottery,
        bytes32 _keyHash,
        uint256 _fee
    ) VRFConsumerBase(_vrfCoordinator, _linkToken) {
        keyHash = _keyHash;
        fee = _fee;
        lottery = _lottery;
    }

    /**
     * Requests randomness from a user-provided seed
     */
    function getRandomNumber(uint256 lotteryId) public onlyLottery returns (bytes32 requestId) {
        require(keyHash != bytes32(0), "Must have valid key hash");
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        requester = msg.sender;
        currentLotteryId = lotteryId;
        return requestRandomness(keyHash, fee);
    }

    function setLottery(address _lottery) external onlyOwner {
        lottery = _lottery;
    }

    function withdrawAllLink() external onlyOwner {
        LINK.transfer(msg.sender, LINK.balanceOf(address(this)));
    }

    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        ILottery(requester).numbersDrawn(currentLotteryId, requestId, randomness);
        randomResult = randomness;
    }
}
