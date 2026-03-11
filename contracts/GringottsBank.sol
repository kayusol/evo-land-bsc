// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title GringottsBank
 * @dev RING staking bank. Users lock RING for a duration and receive KTON.
 *      BSC version: local staking only, no Darwinia cross-chain.
 *
 *      KTON formula (simplified from official):
 *      ktonReward = (months * 67 + 197) / 197 - 1  (expressed as ppm of staked RING)
 *      Where months = duration / 30 days (1-36 months)
 */
interface IKtonToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract GringottsBank is Ownable {

    uint256 public constant MONTH = 30 days;
    uint256 public constant MAX_MONTHS = 36;
    uint256 public constant MIN_MONTHS = 1;
    // Penalty for early unlock: 3x KTON must be returned
    uint256 public constant PENALTY_MULTIPLIER = 3;

    struct Stake {
        uint256 amount;     // RING staked
        uint256 startTime;
        uint256 months;     // lock duration in months
        uint256 ktonMinted; // KTON minted for this stake
        bool    active;
    }

    IERC20      public ring;
    IKtonToken  public kton;

    mapping(address => Stake[]) public stakes;

    event Staked(address indexed user, uint256 stakeId, uint256 amount, uint256 months, uint256 ktonMinted);
    event Unstaked(address indexed user, uint256 stakeId, uint256 amount, bool earlyUnlock, uint256 ktonPenalty);

    constructor(address _ring, address _kton) Ownable(msg.sender) {
        ring = IERC20(_ring);
        kton = IKtonToken(_kton);
    }

    /**
     * @dev Stake RING for `_months` months (1-36). Receive KTON immediately.
     */
    function stakeRING(uint256 amount, uint256 _months) external {
        require(amount > 0, "Amount must be > 0");
        require(_months >= MIN_MONTHS && _months <= MAX_MONTHS, "Invalid lock period");

        require(ring.transferFrom(msg.sender, address(this), amount), "RING transfer failed");

        uint256 ktonReward = calculateKton(amount, _months);

        uint256 stakeId = stakes[msg.sender].length;
        stakes[msg.sender].push(Stake({
            amount:     amount,
            startTime:  block.timestamp,
            months:     _months,
            ktonMinted: ktonReward,
            active:     true
        }));

        kton.mint(msg.sender, ktonReward);

        emit Staked(msg.sender, stakeId, amount, _months, ktonReward);
    }

    /**
     * @dev Unstake RING after lock expires. No penalty.
     *      Early unstake: must return 3x KTON as penalty.
     */
    function unstakeRING(uint256 stakeId, bool earlyUnlock) external {
        Stake storage s = stakes[msg.sender][stakeId];
        require(s.active, "Stake not active");

        bool expired = block.timestamp >= s.startTime + s.months * MONTH;

        if (!expired) {
            require(earlyUnlock, "Lock not expired. Set earlyUnlock=true to pay penalty");
            uint256 penalty = s.ktonMinted * PENALTY_MULTIPLIER;
            kton.burn(msg.sender, penalty);
            emit Unstaked(msg.sender, stakeId, s.amount, true, penalty);
        } else {
            emit Unstaked(msg.sender, stakeId, s.amount, false, 0);
        }

        uint256 amount = s.amount;
        s.active = false;

        require(ring.transfer(msg.sender, amount), "RING return failed");
    }

    /**
     * @dev Calculate KTON reward using official formula.
     *      Official: n months staking = (67n + 197)/(197) - 1 fraction of staked amount in ppm
     *      Simplified to integers: kton = amount * (67*months + 197 - 197) / 197 / 1e6
     *      = amount * 67 * months / 197 / 1e6
     *      We scale by 1e18 for wei precision.
     */
    function calculateKton(uint256 amount, uint256 _months) public pure returns (uint256) {
        // Simple proportional formula (matches official spirit)
        // Base: staking 1 RING for 1 month = ~0.00034 KTON
        // 36 months = ~0.012 KTON per RING
        return amount * 67 * _months / 197 / 10000;
    }

    function getStake(address user, uint256 stakeId) external view returns (
        uint256 amount,
        uint256 startTime,
        uint256 months,
        uint256 ktonMinted,
        bool active,
        bool expired
    ) {
        Stake storage s = stakes[user][stakeId];
        return (s.amount, s.startTime, s.months, s.ktonMinted, s.active,
                block.timestamp >= s.startTime + s.months * MONTH);
    }

    function getStakeCount(address user) external view returns (uint256) {
        return stakes[user].length;
    }
}
