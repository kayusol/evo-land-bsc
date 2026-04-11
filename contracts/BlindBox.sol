// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IApostleNFT {
    function mint(address to, uint8 strength, uint8 element, uint256 genes) external returns (uint256);
}
interface IDrillNFT {
    function mint(address to, uint8 tier, uint8 affinity) external returns (uint256);
}
interface IERC20Transfer {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/// @title BlindBox v2 — 使徒 mint 时生成兼容 Evolution Land 的随机基因
contract BlindBox {
    address public owner;
    address public ring;
    address public apostleNFT;
    address public drillNFT;
    address public treasury;
    uint256 public apostleBoxPrice;
    uint256 public drillBoxPrice;
    uint256 public nonce;

    event BoxOpened(address indexed buyer, string boxType, uint256 tokenId, uint8 attr1, uint8 attr2);
    modifier onlyOwner() { require(msg.sender == owner, "!owner"); _; }

    constructor(address _ring, address _apostle, address _drill, address _treasury, uint256 _ap, uint256 _dp) {
        owner=msg.sender; ring=_ring; apostleNFT=_apostle; drillNFT=_drill;
        treasury=_treasury; apostleBoxPrice=_ap; drillBoxPrice=_dp;
    }

    function setPrice(uint256 a, uint256 d) external onlyOwner { apostleBoxPrice=a; drillBoxPrice=d; }
    function setTreasury(address t) external onlyOwner { treasury=t; }

    function buyApostleBox() external returns (uint256 tokenId) {
        _pay(apostleBoxPrice);
        uint256 seed = _rand();
        (uint8 str, uint8 elem, uint256 genes) = _apostleAttrs(seed);
        tokenId = IApostleNFT(apostleNFT).mint(msg.sender, str, elem, genes);
        emit BoxOpened(msg.sender, "apostle", tokenId, str, elem);
    }

    function buyDrillBox() external returns (uint256 tokenId) {
        _pay(drillBoxPrice);
        uint256 seed = _rand();
        uint8 aff = uint8(seed % 5);
        uint8 tier = _drillTier(seed >> 8);
        tokenId = IDrillNFT(drillNFT).mint(msg.sender, tier, aff);
        emit BoxOpened(msg.sender, "drill", tokenId, tier, aff);
    }

    function buyApostleBoxBatch(uint256 count) external {
        require(count > 0 && count <= 10, "1-10");
        _pay(apostleBoxPrice * count);
        for (uint256 i; i < count; i++) {
            uint256 seed = _rand();
            (uint8 str, uint8 elem, uint256 genes) = _apostleAttrs(seed);
            uint256 tid = IApostleNFT(apostleNFT).mint(msg.sender, str, elem, genes);
            emit BoxOpened(msg.sender, "apostle", tid, str, elem);
        }
    }

    function buyDrillBoxBatch(uint256 count) external {
        require(count > 0 && count <= 10, "1-10");
        _pay(drillBoxPrice * count);
        for (uint256 i; i < count; i++) {
            uint256 seed = _rand();
            uint8 aff = uint8(seed % 5);
            uint8 tier = _drillTier(seed >> 8);
            uint256 tid = IDrillNFT(drillNFT).mint(msg.sender, tier, aff);
            emit BoxOpened(msg.sender, "drill", tid, tier, aff);
        }
    }

    // genes 生成：兼容 Evolution Land 格式
    // bit241 = gender (0=female, 1=male)
    // bits242-243 = race = 0 (human)
    // 其余位 = 随机外貌特征
    function _apostleAttrs(uint256 seed) internal pure
        returns (uint8 str, uint8 elem, uint256 genes)
    {
        elem = uint8(seed % 5);
        str  = _apostleStrength(seed >> 8);
        genes = seed;
        if ((seed >> 30) & 1 == 1) genes |= (uint256(1) << 241);
        else genes &= ~(uint256(1) << 241);
        genes &= ~(uint256(3) << 242); // race=0
    }

    function _pay(uint256 amount) internal {
        require(IERC20Transfer(ring).transferFrom(msg.sender, treasury, amount), "ring fail");
    }

    function _rand() internal returns (uint256) {
        nonce++;
        return uint256(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, msg.sender, nonce)));
    }

    function _apostleStrength(uint256 roll) internal pure returns (uint8) {
        uint256 r = roll % 10000;
        if (r < 7000) return uint8(10 + (roll >> 16) % 30);
        if (r < 9000) return uint8(40 + (roll >> 16) % 30);
        if (r < 9900) return uint8(70 + (roll >> 16) % 20);
        return uint8(90 + (roll >> 16) % 11);
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
