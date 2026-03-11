// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./SettingsRegistry.sol";

/**
 * @title ClockAuction
 * @dev Dutch auction for land and apostle NFTs.
 *      Price decays linearly from startPrice to endPrice over duration.
 *      Buyer pays in RING tokens. 4% cut to revenue pool.
 */
contract ClockAuction is Ownable, ReentrancyGuard {

    bytes32 public constant CONTRACT_RING_ERC20_TOKEN = "CONTRACT_RING_ERC20_TOKEN";
    bytes32 public constant CONTRACT_REVENUE_POOL     = "CONTRACT_REVENUE_POOL";
    bytes32 public constant CONTRACT_OBJECT_OWNERSHIP = "CONTRACT_OBJECT_OWNERSHIP";

    uint256 public constant AUCTION_CUT = 400;   // 4% in basis points
    uint256 public constant CUT_BASE    = 10000;

    struct Auction {
        address seller;
        uint128 startPrice;
        uint128 endPrice;
        uint64  duration;
        uint64  startedAt;
        bool    active;
    }

    SettingsRegistry public registry;
    mapping(uint256 => Auction) public auctions;

    event AuctionCreated(uint256 indexed tokenId, address indexed seller, uint256 startPrice, uint256 endPrice, uint256 duration);
    event AuctionSuccessful(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);
    event AuctionCancelled(uint256 indexed tokenId);

    constructor(address _registry) Ownable(msg.sender) {
        registry = SettingsRegistry(_registry);
    }

    function createAuction(
        uint256 tokenId,
        uint256 startPrice,
        uint256 endPrice,
        uint256 duration
    ) external nonReentrant {
        require(duration >= 60 && duration <= 30 days, "Invalid duration");
        require(startPrice >= endPrice, "Start must be >= end");

        IERC721 nft = IERC721(registry.addressOf(CONTRACT_OBJECT_OWNERSHIP));
        require(nft.ownerOf(tokenId) == msg.sender, "Not owner");

        nft.transferFrom(msg.sender, address(this), tokenId);

        auctions[tokenId] = Auction({
            seller:     msg.sender,
            startPrice: uint128(startPrice),
            endPrice:   uint128(endPrice),
            duration:   uint64(duration),
            startedAt:  uint64(block.timestamp),
            active:     true
        });

        emit AuctionCreated(tokenId, msg.sender, startPrice, endPrice, duration);
    }

    function bid(uint256 tokenId, uint256 maxPrice) external nonReentrant {
        Auction storage auction = auctions[tokenId];
        require(auction.active, "No active auction");

        uint256 price = getCurrentPrice(tokenId);
        require(maxPrice >= price, "Price too low");

        IERC20 ring = IERC20(registry.addressOf(CONTRACT_RING_ERC20_TOKEN));
        require(ring.transferFrom(msg.sender, address(this), price), "RING transfer failed");

        uint256 cut = (price * AUCTION_CUT) / CUT_BASE;
        uint256 sellerProceeds = price - cut;

        require(ring.transfer(auction.seller, sellerProceeds), "Seller payment failed");

        address revenuePool = registry.addressOf(CONTRACT_REVENUE_POOL);
        if (revenuePool != address(0) && cut > 0) {
            require(ring.transfer(revenuePool, cut), "Revenue pool payment failed");
        }

        address seller = auction.seller;
        delete auctions[tokenId];

        IERC721 nft = IERC721(registry.addressOf(CONTRACT_OBJECT_OWNERSHIP));
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        emit AuctionSuccessful(tokenId, msg.sender, seller, price);
    }

    function cancelAuction(uint256 tokenId) external nonReentrant {
        Auction storage auction = auctions[tokenId];
        require(auction.active, "No active auction");
        require(auction.seller == msg.sender || msg.sender == owner(), "Not seller");

        address seller = auction.seller;
        delete auctions[tokenId];

        IERC721 nft = IERC721(registry.addressOf(CONTRACT_OBJECT_OWNERSHIP));
        nft.safeTransferFrom(address(this), seller, tokenId);

        emit AuctionCancelled(tokenId);
    }

    function getCurrentPrice(uint256 tokenId) public view returns (uint256) {
        Auction storage auction = auctions[tokenId];
        require(auction.active, "No active auction");

        uint256 elapsed = block.timestamp - auction.startedAt;
        if (elapsed >= auction.duration) {
            return auction.endPrice;
        }

        uint256 priceDiff = auction.startPrice > auction.endPrice
            ? auction.startPrice - auction.endPrice
            : 0;

        return auction.startPrice - (priceDiff * elapsed / auction.duration);
    }

    function getAuction(uint256 tokenId) external view returns (
        address seller,
        uint256 startPrice,
        uint256 endPrice,
        uint256 duration,
        uint256 startedAt,
        bool active,
        uint256 currentPrice
    ) {
        Auction storage a = auctions[tokenId];
        return (a.seller, a.startPrice, a.endPrice, a.duration, a.startedAt,
                a.active, a.active ? getCurrentPrice(tokenId) : 0);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
