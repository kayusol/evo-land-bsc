// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./SettingsRegistry.sol";
import "./LandBase.sol";

/**
 * @title LandResource
 * @dev Manages resource mining on lands.
 *      Apostles assigned to a land accumulate resources over time based on land resource rates.
 *      Resources claimable by land owner.
 */
interface IResourceToken {
    function mint(address to, uint256 amount) external;
}

contract LandResource is Ownable {

    bytes32 public constant CONTRACT_LAND_BASE          = "CONTRACT_LAND_BASE";
    bytes32 public constant CONTRACT_OBJECT_OWNERSHIP   = "CONTRACT_OBJECT_OWNERSHIP";
    bytes32 public constant CONTRACT_GOLD_ERC20_TOKEN   = "CONTRACT_GOLD_ERC20_TOKEN";
    bytes32 public constant CONTRACT_WOOD_ERC20_TOKEN   = "CONTRACT_WOOD_ERC20_TOKEN";
    bytes32 public constant CONTRACT_WATER_ERC20_TOKEN  = "CONTRACT_WATER_ERC20_TOKEN";
    bytes32 public constant CONTRACT_FIRE_ERC20_TOKEN   = "CONTRACT_FIRE_ERC20_TOKEN";
    bytes32 public constant CONTRACT_SOIL_ERC20_TOKEN   = "CONTRACT_SOIL_ERC20_TOKEN";

    // Base resource production per unit rate per second (scaled by 1e18)
    // Official: ~1 unit per resource-rate-point per day
    uint256 public constant BASE_RATE_PER_SEC = 1e18 / 1 days; // 1 resource per rate-point per day

    SettingsRegistry public registry;

    // landTokenId => last claim timestamp
    mapping(uint256 => uint256) public lastClaimTime;
    // landTokenId => apostle count working
    mapping(uint256 => uint256) public apostleCount;

    event StartMining(uint256 indexed landTokenId, uint256 indexed apostleTokenId, address indexed owner);
    event StopMining(uint256 indexed landTokenId, uint256 indexed apostleTokenId);
    event ResourceClaimed(uint256 indexed landTokenId, address indexed owner, uint256[5] amounts);

    constructor(address _registry) Ownable(msg.sender) {
        registry = SettingsRegistry(_registry);
    }

    /**
     * @dev Start apostle mining on a land.
     *      Land owner assigns apostle. Resources start accumulating.
     */
    function startMining(uint256 landTokenId, uint256 apostleTokenId) external {
        // Claim any pending resources first
        _claimResources(landTokenId);

        apostleCount[landTokenId]++;
        if (lastClaimTime[landTokenId] == 0) {
            lastClaimTime[landTokenId] = block.timestamp;
        }

        emit StartMining(landTokenId, apostleTokenId, msg.sender);
    }

    /**
     * @dev Stop apostle mining
     */
    function stopMining(uint256 landTokenId, uint256 apostleTokenId) external {
        require(apostleCount[landTokenId] > 0, "No apostles mining");
        _claimResources(landTokenId);
        apostleCount[landTokenId]--;
        emit StopMining(landTokenId, apostleTokenId);
    }

    /**
     * @dev Claim all accumulated resources for a land
     */
    function claimAllResources(uint256 landTokenId) external {
        _claimResources(landTokenId);
    }

    function _claimResources(uint256 landTokenId) internal {
        if (lastClaimTime[landTokenId] == 0) {
            lastClaimTime[landTokenId] = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - lastClaimTime[landTokenId];
        if (elapsed == 0 || apostleCount[landTokenId] == 0) {
            lastClaimTime[landTokenId] = block.timestamp;
            return;
        }

        LandBase landBase = LandBase(registry.addressOf(CONTRACT_LAND_BASE));
        (uint256 resourceRateAttr,,,) = landBase.getLandAttr(landTokenId);

        address landOwner = _getLandOwner(landTokenId);
        if (landOwner == address(0)) {
            lastClaimTime[landTokenId] = block.timestamp;
            return;
        }

        bytes32[5] memory resourceKeys = [
            CONTRACT_GOLD_ERC20_TOKEN,
            CONTRACT_WOOD_ERC20_TOKEN,
            CONTRACT_WATER_ERC20_TOKEN,
            CONTRACT_FIRE_ERC20_TOKEN,
            CONTRACT_SOIL_ERC20_TOKEN
        ];

        uint256[5] memory amounts;
        for (uint8 i = 0; i < 5; i++) {
            uint16 rate = uint16((resourceRateAttr >> (i * 16)) & 0xFFFF);
            if (rate == 0) continue;

            // amount = rate * elapsed * BASE_RATE_PER_SEC * apostleCount
            uint256 amount = uint256(rate) * elapsed * BASE_RATE_PER_SEC * apostleCount[landTokenId] / 1e18;
            if (amount == 0) continue;

            address token = registry.addressOf(resourceKeys[i]);
            if (token != address(0)) {
                IResourceToken(token).mint(landOwner, amount);
                amounts[i] = amount;
            }
        }

        lastClaimTime[landTokenId] = block.timestamp;
        emit ResourceClaimed(landTokenId, landOwner, amounts);
    }

    /**
     * @dev Calculate pending resources (view only)
     */
    function availableResources(uint256 landTokenId) external view returns (uint256[5] memory amounts) {
        if (lastClaimTime[landTokenId] == 0 || apostleCount[landTokenId] == 0) {
            return amounts;
        }

        uint256 elapsed = block.timestamp - lastClaimTime[landTokenId];
        LandBase landBase = LandBase(registry.addressOf(CONTRACT_LAND_BASE));
        (uint256 resourceRateAttr,,,) = landBase.getLandAttr(landTokenId);

        for (uint8 i = 0; i < 5; i++) {
            uint16 rate = uint16((resourceRateAttr >> (i * 16)) & 0xFFFF);
            if (rate == 0) continue;
            amounts[i] = uint256(rate) * elapsed * BASE_RATE_PER_SEC * apostleCount[landTokenId] / 1e18;
        }
    }

    function _getLandOwner(uint256 landTokenId) internal view returns (address) {
        try IERC721(registry.addressOf(CONTRACT_OBJECT_OWNERSHIP)).ownerOf(landTokenId) returns (address owner) {
            return owner;
        } catch {
            return address(0);
        }
    }
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
}
