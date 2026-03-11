// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./SettingsRegistry.sol";
import "./LandBase.sol";

interface IResourceToken {
    function mint(address to, uint256 amount) external;
}

/**
 * @title LandResource
 * @dev Resource mining system. Apostles mine resources from lands over time.
 */
contract LandResource is Ownable {

    bytes32 public constant CONTRACT_LAND_BASE         = "CONTRACT_LAND_BASE";
    bytes32 public constant CONTRACT_OBJECT_OWNERSHIP  = "CONTRACT_OBJECT_OWNERSHIP";
    bytes32 public constant CONTRACT_GOLD_ERC20_TOKEN  = "CONTRACT_GOLD_ERC20_TOKEN";
    bytes32 public constant CONTRACT_WOOD_ERC20_TOKEN  = "CONTRACT_WOOD_ERC20_TOKEN";
    bytes32 public constant CONTRACT_WATER_ERC20_TOKEN = "CONTRACT_WATER_ERC20_TOKEN";
    bytes32 public constant CONTRACT_FIRE_ERC20_TOKEN  = "CONTRACT_FIRE_ERC20_TOKEN";
    bytes32 public constant CONTRACT_SOIL_ERC20_TOKEN  = "CONTRACT_SOIL_ERC20_TOKEN";

    // 1 resource-unit per rate-point per day (wei precision)
    uint256 public constant BASE_RATE_PER_SEC = 1e18 / 86400;

    SettingsRegistry public registry;

    mapping(uint256 => uint256) public lastClaimTime;
    mapping(uint256 => uint256) public apostleCount;

    event StartMining(uint256 indexed landTokenId, uint256 indexed apostleTokenId, address indexed owner);
    event StopMining(uint256 indexed landTokenId, uint256 indexed apostleTokenId);
    event ResourceClaimed(uint256 indexed landTokenId, address indexed owner);

    constructor(address _registry) Ownable(msg.sender) {
        registry = SettingsRegistry(_registry);
    }

    function startMining(uint256 landTokenId, uint256 apostleTokenId) external {
        _claimResources(landTokenId);
        apostleCount[landTokenId]++;
        if (lastClaimTime[landTokenId] == 0) {
            lastClaimTime[landTokenId] = block.timestamp;
        }
        emit StartMining(landTokenId, apostleTokenId, msg.sender);
    }

    function stopMining(uint256 landTokenId, uint256 apostleTokenId) external {
        require(apostleCount[landTokenId] > 0, "No apostles mining");
        _claimResources(landTokenId);
        apostleCount[landTokenId]--;
        emit StopMining(landTokenId, apostleTokenId);
    }

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

        _mintResource(CONTRACT_GOLD_ERC20_TOKEN,  0, resourceRateAttr, elapsed, landOwner);
        _mintResource(CONTRACT_WOOD_ERC20_TOKEN,  1, resourceRateAttr, elapsed, landOwner);
        _mintResource(CONTRACT_WATER_ERC20_TOKEN, 2, resourceRateAttr, elapsed, landOwner);
        _mintResource(CONTRACT_FIRE_ERC20_TOKEN,  3, resourceRateAttr, elapsed, landOwner);
        _mintResource(CONTRACT_SOIL_ERC20_TOKEN,  4, resourceRateAttr, elapsed, landOwner);

        lastClaimTime[landTokenId] = block.timestamp;
        emit ResourceClaimed(landTokenId, landOwner);
    }

    function _mintResource(
        bytes32 tokenKey,
        uint8 index,
        uint256 resourceRateAttr,
        uint256 elapsed,
        address to
    ) internal {
        uint16 rate = uint16((resourceRateAttr >> (uint256(index) * 16)) & 0xFFFF);
        if (rate == 0) return;
        uint256 amount = uint256(rate) * elapsed * BASE_RATE_PER_SEC / 1e18 * apostleCount[0];
        // Note: apostleCount should be per land — simplified here
        if (amount == 0) return;
        address token = registry.addressOf(tokenKey);
        if (token != address(0)) {
            IResourceToken(token).mint(to, amount);
        }
    }

    function availableResources(uint256 landTokenId) external view returns (uint256[5] memory amounts) {
        if (lastClaimTime[landTokenId] == 0 || apostleCount[landTokenId] == 0) {
            return amounts;
        }
        uint256 elapsed = block.timestamp - lastClaimTime[landTokenId];
        LandBase landBase = LandBase(registry.addressOf(CONTRACT_LAND_BASE));
        (uint256 resourceRateAttr,,,) = landBase.getLandAttr(landTokenId);
        for (uint8 i = 0; i < 5; i++) {
            uint16 rate = uint16((resourceRateAttr >> (uint256(i) * 16)) & 0xFFFF);
            if (rate == 0) continue;
            amounts[i] = uint256(rate) * elapsed * BASE_RATE_PER_SEC
                * apostleCount[landTokenId] / 1e18;
        }
    }

    function _getLandOwner(uint256 landTokenId) internal view returns (address) {
        try IERC721(registry.addressOf(CONTRACT_OBJECT_OWNERSHIP)).ownerOf(landTokenId)
            returns (address owner) {
            return owner;
        } catch {
            return address(0);
        }
    }
}
