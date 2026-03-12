// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ReferralReward
 * @notice 5-level referral system. MiningSystem calls distributeReward() after minting.
 *
 * Rates (basis points out of 10000):
 *   L1 = 500  (5.0%)
 *   L2 = 300  (3.0%)
 *   L3 = 200  (2.0%)
 *   L4 = 100  (1.0%)
 *   L5 =  50  (0.5%)
 */
contract ReferralReward {
    address public owner;
    address public miningSystem;

    uint256 public constant MAX_LEVELS = 5;
    uint256 public constant RATE_BASE  = 10000;
    uint256[5] public RATES;

    mapping(address => address) public referrer;
    mapping(address => bool)    public bound;
    // user => token => total earned
    mapping(address => mapping(address => uint256)) public totalEarned;

    event Bound(address indexed user, address indexed ref);
    event ReferralRewarded(address indexed earner, address indexed miner, address indexed token, uint256 amount, uint8 level);
    event MiningSystemSet(address addr);

    modifier onlyOwner()  { require(msg.sender == owner,         "!owner");  _; }
    modifier onlyMining() { require(msg.sender == miningSystem,  "!mining"); _; }

    constructor() {
        owner = msg.sender;
        RATES = [500, 300, 200, 100, 50];
    }

    function setMiningSystem(address a) external onlyOwner {
        miningSystem = a;
        emit MiningSystemSet(a);
    }

    function setRates(uint256[5] calldata r) external onlyOwner {
        uint256 total;
        for (uint i; i < 5; i++) total += r[i];
        require(total <= 2000, "max 20%");
        RATES = r;
    }

    /// @notice User binds their referrer (one-time, immutable)
    function bind(address _ref) external {
        require(!bound[msg.sender],       "already bound");
        require(_ref != address(0),       "zero");
        require(_ref != msg.sender,       "self");
        require(!_isAncestor(msg.sender, _ref), "circular");
        referrer[msg.sender] = _ref;
        bound[msg.sender]    = true;
        emit Bound(msg.sender, _ref);
    }

    /**
     * @notice Called by MiningSystem after minting resources to miner.
     *         This contract must hold enough token balance (MiningSystem mints extra
     *         and transfers to this contract before calling).
     */
    function distributeReward(address miner, address token, uint256 amount) external onlyMining {
        address cur = miner;
        for (uint8 lvl; lvl < MAX_LEVELS; lvl++) {
            address up = referrer[cur];
            if (up == address(0)) break;
            uint256 reward = amount * RATES[lvl] / RATE_BASE;
            if (reward > 0) {
                _safeTransfer(token, up, reward);
                totalEarned[up][token] += reward;
                emit ReferralRewarded(up, miner, token, reward, lvl + 1);
            }
            cur = up;
        }
    }

    function getAncestors(address user) external view returns (address[5] memory a) {
        address cur = user;
        for (uint8 i; i < MAX_LEVELS; i++) {
            address up = referrer[cur];
            if (up == address(0)) break;
            a[i] = up; cur = up;
        }
    }

    function getRates() external view returns (uint256[5] memory) { return RATES; }

    function earned(address user, address token) external view returns (uint256) {
        return totalEarned[user][token];
    }

    function _isAncestor(address user, address target) internal view returns (bool) {
        address cur = user;
        for (uint8 i; i < MAX_LEVELS + 1; i++) {
            cur = referrer[cur];
            if (cur == address(0)) return false;
            if (cur == target)     return true;
        }
        return false;
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "transfer failed");
    }
}
