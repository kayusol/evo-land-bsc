// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ObjectOwnership.sol";
import "./SettingsRegistry.sol";

/**
 * @title LandBase
 * @dev Core land contract. Stores land attributes (resource rates, coordinates, mask).
 *      BSC version: 10000 lands, x[0,99] y[0,99]
 *      tokenId encoding: ((x + 1000000) << 32) | (y + 1000000)  (simplified from official InterstellarEncoder)
 */
contract LandBase is Ownable {

    // SettingIds keys
    bytes32 public constant CONTRACT_OBJECT_OWNERSHIP = "CONTRACT_OBJECT_OWNERSHIP";

    // Map bounds for BSC: 100x100 = 10000 lands
    int256 public constant MAP_MIN_X = 0;
    int256 public constant MAP_MAX_X = 99;
    int256 public constant MAP_MIN_Y = 0;
    int256 public constant MAP_MAX_Y = 99;

    struct LandAttr {
        uint256 resourceRateAttr; // packed: gold(16) | wood(16) | water(16) | fire(16) | soil(16)
        uint8   mask;             // 1=reserved, 2=special, 4=hasBox
        address originalOwner;
        uint256 createdAt;
    }

    SettingsRegistry public registry;
    mapping(uint256 => LandAttr) public tokenIdToLandAttr;
    mapping(uint256 => uint256) public tokenIndexToTokenId; // 1-based index -> tokenId
    uint256 public totalLands;

    mapping(address => bool) public operators;

    event LandAssigned(uint256 indexed tokenId, int256 x, int256 y, address to, uint256 resourceRateAttr, uint8 mask);
    event OperatorSet(address indexed operator, bool enabled);

    modifier onlyOperator() {
        require(operators[msg.sender] || msg.sender == owner(), "Not operator");
        _;
    }

    constructor(address _registry) Ownable(msg.sender) {
        registry = SettingsRegistry(_registry);
    }

    function setOperator(address _operator, bool _enabled) external onlyOwner {
        operators[_operator] = _enabled;
        emit OperatorSet(_operator, _enabled);
    }

    /**
     * @dev Encode (x, y) to tokenId. Simple bijective mapping.
     *      tokenId = (x * 10000 + y) + 1  (1-based, so 0 means "no land")
     */
    function encodeTokenId(int256 x, int256 y) public pure returns (uint256) {
        require(x >= MAP_MIN_X && x <= MAP_MAX_X, "x out of range");
        require(y >= MAP_MIN_Y && y <= MAP_MAX_Y, "y out of range");
        return uint256(x * 10000 + y) + 1;
    }

    function decodeTokenId(uint256 tokenId) public pure returns (int256 x, int256 y) {
        require(tokenId > 0, "invalid tokenId");
        uint256 idx = tokenId - 1;
        x = int256(idx / 10000);
        y = int256(idx % 10000);
    }

    /**
     * @dev Assign a new land to recipient (called by deploy script to initialize genesis lands)
     */
    function assignNewLand(
        int256 x,
        int256 y,
        address to,
        uint256 resourceRateAttr,
        uint8 mask
    ) external onlyOperator returns (uint256 tokenId) {
        tokenId = encodeTokenId(x, y);
        require(tokenIdToLandAttr[tokenId].createdAt == 0, "Land already assigned");

        tokenIdToLandAttr[tokenId] = LandAttr({
            resourceRateAttr: resourceRateAttr,
            mask: mask,
            originalOwner: to,
            createdAt: block.timestamp
        });

        totalLands++;
        tokenIndexToTokenId[totalLands] = tokenId;

        ObjectOwnership oo = ObjectOwnership(registry.addressOf(CONTRACT_OBJECT_OWNERSHIP));
        oo.mint(to, tokenId);

        emit LandAssigned(tokenId, x, y, to, resourceRateAttr, mask);
    }

    /**
     * @dev Batch assign lands for efficiency during initialization
     */
    function batchAssignLands(
        int256[] calldata xs,
        int256[] calldata ys,
        address to,
        uint256[] calldata resourceRateAttrs,
        uint8[] calldata masks
    ) external onlyOperator {
        require(xs.length == ys.length && xs.length == resourceRateAttrs.length, "Length mismatch");
        for (uint256 i = 0; i < xs.length; i++) {
            uint256 tokenId = encodeTokenId(xs[i], ys[i]);
            if (tokenIdToLandAttr[tokenId].createdAt != 0) continue;

            tokenIdToLandAttr[tokenId] = LandAttr({
                resourceRateAttr: resourceRateAttrs[i],
                mask: masks[i],
                originalOwner: to,
                createdAt: block.timestamp
            });

            totalLands++;
            tokenIndexToTokenId[totalLands] = tokenId;

            ObjectOwnership oo = ObjectOwnership(registry.addressOf(CONTRACT_OBJECT_OWNERSHIP));
            oo.mint(to, tokenId);

            emit LandAssigned(tokenId, xs[i], ys[i], to, resourceRateAttrs[i], masks[i]);
        }
    }

    function getLandResourceRate(uint256 tokenId, uint8 resourceIndex) external view returns (uint16) {
        uint256 attr = tokenIdToLandAttr[tokenId].resourceRateAttr;
        return uint16((attr >> (resourceIndex * 16)) & 0xFFFF);
    }

    function getLandAttr(uint256 tokenId) external view returns (
        uint256 resourceRateAttr,
        uint8 mask,
        address originalOwner,
        uint256 createdAt
    ) {
        LandAttr storage la = tokenIdToLandAttr[tokenId];
        return (la.resourceRateAttr, la.mask, la.originalOwner, la.createdAt);
    }
}
