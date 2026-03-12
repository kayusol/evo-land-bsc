// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BlindBox
 * @notice Sell blind boxes that randomly mint ApostleNFT or DrillNFT.
 *
 * Randomness: keccak256(block.prevrandao + block.timestamp + msg.sender + nonce)
 * (Good enough for BSC testnet; use Chainlink VRF for mainnet)
 *
 * Rarity table (Apostle):
 *   0-6999  (70%) → Common    strength 10-39
 *   7000-8999(20%) → Rare     strength 40-69
 *   9000-9899( 9%) → Epic     strength 70-89
 *   9900-9999( 1%) → Legend   strength 90-100
 *
 * Drill tier table:
 *   0-3999  (40%) → tier 1
 *   4000-6999(30%) → tier 2
 *   7000-8499(15%) → tier 3
 *   8500-9499(10%) → tier 4
 *   9500-9999( 5%) → tier 5
 */

interface IMintableNFT {
    function mint(address to, uint8 attr1, uint8 attr2) external returns (uint256);
}

interface IERC20Burn {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function burn(address from, uint256 value) external;
}

contract BlindBox {
    address public owner;
    address public ring;
    address public apostleNFT;
    address public drillNFT;
    address public treasury;  // receives RING payments

    uint256 public apostleBoxPrice; // in RING (18 decimals)
    uint256 public drillBoxPrice;
    uint256 public nonce;

    event BoxOpened(address indexed buyer, string boxType, uint256 tokenId, uint8 attr1, uint8 attr2);

    modifier onlyOwner() { require(msg.sender == owner, "!owner"); _; }

    constructor(
        address _ring,
        address _apostle,
        address _drill,
        address _treasury,
        uint256 _apostlePrice,
        uint256 _drillPrice
    ) {
        owner          = msg.sender;
        ring           = _ring;
        apostleNFT     = _apostle;
        drillNFT       = _drill;
        treasury       = _treasury;
        apostleBoxPrice = _apostlePrice;
        drillBoxPrice   = _drillPrice;
    }

    // ── Owner config ─────────────────────────────────────────
    function setPrice(uint256 aPrice, uint256 dPrice) external onlyOwner {
        apostleBoxPrice = aPrice;
        drillBoxPrice   = dPrice;
    }
    function setTreasury(address t) external onlyOwner { treasury = t; }

    // ── Buy Apostle Box ───────────────────────────────────────
    function buyApostleBox() external returns (uint256 tokenId) {
        _pay(apostleBoxPrice);
        uint256 seed = _rand();

        uint8 element  = uint8(seed % 5);                   // 0-4
        uint8 strength = _apostleStrength(seed >> 8);

        tokenId = IMintableNFT(apostleNFT).mint(msg.sender, strength, element);
        emit BoxOpened(msg.sender, "apostle", tokenId, strength, element);
    }

    // ── Buy Drill Box ─────────────────────────────────────────
    function buyDrillBox() external returns (uint256 tokenId) {
        _pay(drillBoxPrice);
        uint256 seed = _rand();

        uint8 affinity = uint8(seed % 5);                   // 0-4
        uint8 tier     = _drillTier(seed >> 8);

        tokenId = IMintableNFT(drillNFT).mint(msg.sender, tier, affinity);
        emit BoxOpened(msg.sender, "drill", tokenId, tier, affinity);
    }

    // ── Batch buy ─────────────────────────────────────────────
    function buyApostleBoxBatch(uint256 count) external {
        require(count > 0 && count <= 10, "1-10");
        _pay(apostleBoxPrice * count);
        for (uint256 i; i < count; i++) {
            uint256 seed   = _rand();
            uint8 element  = uint8(seed % 5);
            uint8 strength = _apostleStrength(seed >> 8);
            uint256 tid    = IMintableNFT(apostleNFT).mint(msg.sender, strength, element);
            emit BoxOpened(msg.sender, "apostle", tid, strength, element);
        }
    }

    function buyDrillBoxBatch(uint256 count) external {
        require(count > 0 && count <= 10, "1-10");
        _pay(drillBoxPrice * count);
        for (uint256 i; i < count; i++) {
            uint256 seed  = _rand();
            uint8 aff     = uint8(seed % 5);
            uint8 tier    = _drillTier(seed >> 8);
            uint256 tid   = IMintableNFT(drillNFT).mint(msg.sender, tier, aff);
            emit BoxOpened(msg.sender, "drill", tid, tier, aff);
        }
    }

    // ── Internal ─────────────────────────────────────────────
    function _pay(uint256 amount) internal {
        require(
            IERC20Burn(ring).transferFrom(msg.sender, treasury, amount),
            "ring transfer failed"
        );
    }

    function _rand() internal returns (uint256) {
        nonce++;
        return uint256(keccak256(abi.encodePacked(
            block.prevrandao,
            block.timestamp,
            msg.sender,
            nonce
        )));
    }

    function _apostleStrength(uint256 roll) internal pure returns (uint8) {
        uint256 r = roll % 10000;
        if (r < 7000) return uint8(10 + (roll >> 16) % 30);   // Common  10-39
        if (r < 9000) return uint8(40 + (roll >> 16) % 30);   // Rare    40-69
        if (r < 9900) return uint8(70 + (roll >> 16) % 20);   // Epic    70-89
        return uint8(90 + (roll >> 16) % 11);                  // Legend  90-100
    }

    function _drillTier(uint256 roll) internal pure returns (uint8) {
        uint256 r = roll % 10000;
        if (r < 4000) return 1;
        if (r < 7000) return 2;
        if (r < 8500) return 3;
        if (r < 9500) return 4;
        return 5;
    }
}
