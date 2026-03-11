// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================================
//  Minimal ERC20 base (no OZ dependency)
// ============================================================
abstract contract ERC20Base {
    string  public name;
    string  public symbol;
    uint8   public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name   = _name;
        symbol = _symbol;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0) && to != address(0), "zero address");
        balanceOf[from] -= amount;
        balanceOf[to]   += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "zero address");
        totalSupply     += amount;
        balanceOf[to]   += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(from != address(0), "zero address");
        balanceOf[from] -= amount;
        totalSupply     -= amount;
        emit Transfer(from, address(0), amount);
    }
}

// ============================================================
//  Minimal Ownable (no OZ dependency)
// ============================================================
abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

// ============================================================
//  Minimal ERC721 base (no OZ dependency)
// ============================================================
abstract contract ERC721Base is Ownable {
    string  public name;
    string  public symbol;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    constructor(string memory _name, string memory _symbol) {
        name   = _name;
        symbol = _symbol;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd // ERC721
            || id == 0x5b5e139f // ERC721Metadata
            || id == 0x01ffc9a7; // ERC165
    }

    function approve(address to, uint256 tokenId) external {
        address tokenOwner = ownerOf[tokenId];
        require(msg.sender == tokenOwner || isApprovedForAll[tokenOwner][msg.sender], "Not authorized");
        getApproved[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        require(_isApproved(msg.sender, tokenId), "Not approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        require(_isApproved(msg.sender, tokenId), "Not approved");
        _transfer(from, to, tokenId);
        _checkReceiver(msg.sender, from, to, tokenId, data);
    }

    function _isApproved(address spender, uint256 tokenId) internal view returns (bool) {
        address tokenOwner = ownerOf[tokenId];
        return spender == tokenOwner
            || isApprovedForAll[tokenOwner][spender]
            || getApproved[tokenId] == spender;
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf[tokenId] == from, "Wrong owner");
        require(to != address(0), "zero address");
        delete getApproved[tokenId];
        balanceOf[from]--;
        balanceOf[to]++;
        ownerOf[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0), "zero address");
        require(ownerOf[tokenId] == address(0), "Already minted");
        balanceOf[to]++;
        ownerOf[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    function _burn(uint256 tokenId) internal {
        address tokenOwner = ownerOf[tokenId];
        require(tokenOwner != address(0), "Not minted");
        balanceOf[tokenOwner]--;
        delete ownerOf[tokenId];
        delete getApproved[tokenId];
        emit Transfer(tokenOwner, address(0), tokenId);
    }

    function _checkReceiver(address operator, address from, address to, uint256 tokenId, bytes memory data) internal {
        if (to.code.length > 0) {
            bytes4 retval = IERC721Receiver(to).onERC721Received(operator, from, tokenId, data);
            require(retval == 0x150b7a02, "non ERC721Receiver");
        }
    }
}

interface IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4);
}

// ============================================================
//  SettingsRegistry
// ============================================================
contract SettingsRegistry is Ownable {
    mapping(bytes32 => uint256)  public uintOf;
    mapping(bytes32 => address)  public addressOf;
    mapping(bytes32 => bool)     public boolOf;
    mapping(bytes32 => int256)   public intOf;
    mapping(bytes32 => string)   public stringOf;

    function setUintProperty(bytes32 k, uint256 v)          external onlyOwner { uintOf[k]    = v; }
    function setAddressProperty(bytes32 k, address v)       external onlyOwner { addressOf[k] = v; }
    function setBoolProperty(bytes32 k, bool v)             external onlyOwner { boolOf[k]    = v; }
    function setIntProperty(bytes32 k, int256 v)            external onlyOwner { intOf[k]     = v; }
    function setStringProperty(bytes32 k, string calldata v) external onlyOwner { stringOf[k] = v; }
}

// ============================================================
//  ObjectOwnership  (ERC721 NFT for lands & apostles)
// ============================================================
contract ObjectOwnership is ERC721Base {
    mapping(address => bool) public operators;

    modifier onlyOperator() {
        require(operators[msg.sender] || msg.sender == owner, "Not operator");
        _;
    }

    constructor() ERC721Base("Evolution Land Object", "ELO") {}

    function setOperator(address op, bool enabled) external onlyOwner {
        operators[op] = enabled;
    }

    function mint(address to, uint256 tokenId) external onlyOperator {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) external onlyOperator {
        _burn(tokenId);
    }

    // Operator override: bypass per-token approval
    function transferFrom(address from, address to, uint256 tokenId) public override {
        if (operators[msg.sender]) { _transfer(from, to, tokenId); }
        else { super.transferFrom(from, to, tokenId); }
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        if (operators[msg.sender]) {
            _transfer(from, to, tokenId);
            _checkReceiver(msg.sender, from, to, tokenId, data);
        } else {
            super.safeTransferFrom(from, to, tokenId, data);
        }
    }
}

// ============================================================
//  Operator-mintable ERC20 (base for RING, KTON, resources)
// ============================================================
abstract contract MintableERC20 is ERC20Base, Ownable {
    mapping(address => bool) public operators;

    modifier onlyOperator() {
        require(operators[msg.sender] || msg.sender == owner, "Not operator");
        _;
    }

    constructor(string memory n, string memory s) ERC20Base(n, s) {}

    function setOperator(address op, bool enabled) external onlyOwner {
        operators[op] = enabled;
    }

    function mint(address to, uint256 amount) external onlyOperator {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOperator {
        _burn(from, amount);
    }
}

// ============================================================
//  RING Token  (10000 initial supply to deployer)
// ============================================================
contract RingToken is MintableERC20 {
    constructor() MintableERC20("Evolution Land Ring", "RING") {
        _mint(msg.sender, 10_000 * 1e18);
    }
}

// ============================================================
//  KTON Token
// ============================================================
contract KtonToken is MintableERC20 {
    constructor() MintableERC20("Evolution Land Kton", "KTON") {}
}

// ============================================================
//  Resource Token (reused for GOLD/WOOD/HHO/FIRE/SIOO)
// ============================================================
contract ResourceToken is MintableERC20 {
    constructor(string memory n, string memory s) MintableERC20(n, s) {}
}

// ============================================================
//  RevenuePool
// ============================================================
contract RevenuePool is Ownable {
    address public ring;
    constructor(address _ring) { ring = _ring; }

    function withdraw(address to, uint256 amount) external onlyOwner {
        require(ERC20Base(ring).transfer(to, amount), "failed");
    }

    function balance() external view returns (uint256) {
        return ERC20Base(ring).balanceOf(address(this));
    }
}

// ============================================================
//  LandBase
// ============================================================
contract LandBase is Ownable {
    bytes32 public constant CONTRACT_OBJECT_OWNERSHIP =
        keccak256(abi.encodePacked("CONTRACT_OBJECT_OWNERSHIP"));

    struct LandAttr {
        uint256 resourceRateAttr;
        uint8   mask;
        address originalOwner;
        uint256 createdAt;
    }

    SettingsRegistry public registry;
    mapping(uint256 => LandAttr) public tokenIdToLandAttr;
    mapping(uint256 => uint256)  public tokenIndexToTokenId;
    uint256 public totalLands;
    mapping(address => bool) public operators;

    event LandAssigned(uint256 indexed tokenId, int256 x, int256 y, address to);

    modifier onlyOperator() {
        require(operators[msg.sender] || msg.sender == owner, "Not operator");
        _;
    }

    constructor(address _registry) { registry = SettingsRegistry(_registry); }

    function setOperator(address op, bool enabled) external onlyOwner {
        operators[op] = enabled;
    }

    function encodeTokenId(int256 x, int256 y) public pure returns (uint256) {
        require(x >= 0 && x <= 99 && y >= 0 && y <= 99, "out of range");
        return uint256(x * 10000 + y) + 1;
    }

    function decodeTokenId(uint256 tokenId) public pure returns (int256 x, int256 y) {
        uint256 idx = tokenId - 1;
        x = int256(idx / 10000);
        y = int256(idx % 10000);
    }

    function batchAssignLands(
        int256[] calldata xs, int256[] calldata ys, address to,
        uint256[] calldata rates, uint8[] calldata masks
    ) external onlyOperator {
        ObjectOwnership oo = ObjectOwnership(registry.addressOf(CONTRACT_OBJECT_OWNERSHIP));
        for (uint256 i = 0; i < xs.length; i++) {
            uint256 tid = encodeTokenId(xs[i], ys[i]);
            if (tokenIdToLandAttr[tid].createdAt != 0) continue;
            tokenIdToLandAttr[tid] = LandAttr(rates[i], masks[i], to, block.timestamp);
            totalLands++;
            tokenIndexToTokenId[totalLands] = tid;
            oo.mint(to, tid);
            emit LandAssigned(tid, xs[i], ys[i], to);
        }
    }

    function getLandAttr(uint256 tokenId) external view returns (
        uint256 resourceRateAttr, uint8 mask, address originalOwner, uint256 createdAt
    ) {
        LandAttr storage la = tokenIdToLandAttr[tokenId];
        return (la.resourceRateAttr, la.mask, la.originalOwner, la.createdAt);
    }
}

// ============================================================
//  ClockAuction  (Dutch auction, 4% cut)
// ============================================================
contract ClockAuction is Ownable {
    bytes32 public constant CONTRACT_RING_ERC20_TOKEN =
        keccak256(abi.encodePacked("CONTRACT_RING_ERC20_TOKEN"));
    bytes32 public constant CONTRACT_REVENUE_POOL =
        keccak256(abi.encodePacked("CONTRACT_REVENUE_POOL"));
    bytes32 public constant CONTRACT_OBJECT_OWNERSHIP =
        keccak256(abi.encodePacked("CONTRACT_OBJECT_OWNERSHIP"));

    uint256 public constant AUCTION_CUT = 400;
    uint256 public constant CUT_BASE    = 10000;

    struct Auction {
        address seller;
        uint128 startPrice;
        uint128 endPrice;
        uint64  duration;
        uint64  startedAt;
    }

    SettingsRegistry public registry;
    mapping(uint256 => Auction) public auctions;
    bool private _locked;

    modifier nonReentrant() {
        require(!_locked, "reentrant");
        _locked = true;
        _;
        _locked = false;
    }

    event AuctionCreated(uint256 indexed tokenId, address indexed seller, uint256 startPrice, uint256 endPrice, uint256 duration);
    event AuctionSuccessful(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event AuctionCancelled(uint256 indexed tokenId);

    constructor(address _registry) { registry = SettingsRegistry(_registry); }

    function createAuction(uint256 tokenId, uint256 startPrice, uint256 endPrice, uint256 duration) external nonReentrant {
        require(duration >= 60 && duration <= 30 days, "bad duration");
        require(startPrice >= endPrice, "start >= end");
        ObjectOwnership nft = ObjectOwnership(registry.addressOf(CONTRACT_OBJECT_OWNERSHIP));
        require(nft.ownerOf(tokenId) == msg.sender, "not owner");
        nft.transferFrom(msg.sender, address(this), tokenId);
        auctions[tokenId] = Auction(msg.sender, uint128(startPrice), uint128(endPrice), uint64(duration), uint64(block.timestamp));
        emit AuctionCreated(tokenId, msg.sender, startPrice, endPrice, duration);
    }

    function bid(uint256 tokenId, uint256 maxPrice) external nonReentrant {
        Auction storage a = auctions[tokenId];
        require(a.startedAt > 0, "no auction");
        uint256 price = currentPrice(tokenId);
        require(maxPrice >= price, "price too low");
        ERC20Base ring = ERC20Base(registry.addressOf(CONTRACT_RING_ERC20_TOKEN));
        require(ring.transferFrom(msg.sender, address(this), price), "ring failed");
        uint256 cut = price * AUCTION_CUT / CUT_BASE;
        require(ring.transfer(a.seller, price - cut), "seller pay failed");
        address pool = registry.addressOf(CONTRACT_REVENUE_POOL);
        if (pool != address(0) && cut > 0) ring.transfer(pool, cut);
        address seller = a.seller;
        delete auctions[tokenId];
        ObjectOwnership(registry.addressOf(CONTRACT_OBJECT_OWNERSHIP)).transferFrom(address(this), msg.sender, tokenId);
        emit AuctionSuccessful(tokenId, msg.sender, price);
    }

    function cancelAuction(uint256 tokenId) external nonReentrant {
        Auction storage a = auctions[tokenId];
        require(a.startedAt > 0, "no auction");
        require(a.seller == msg.sender || msg.sender == owner, "not seller");
        address seller = a.seller;
        delete auctions[tokenId];
        ObjectOwnership(registry.addressOf(CONTRACT_OBJECT_OWNERSHIP)).transferFrom(address(this), seller, tokenId);
        emit AuctionCancelled(tokenId);
    }

    function currentPrice(uint256 tokenId) public view returns (uint256) {
        Auction storage a = auctions[tokenId];
        require(a.startedAt > 0, "no auction");
        uint256 elapsed = block.timestamp - a.startedAt;
        if (elapsed >= a.duration) return a.endPrice;
        uint256 diff = a.startPrice > a.endPrice ? a.startPrice - a.endPrice : 0;
        return a.startPrice - diff * elapsed / a.duration;
    }

    // Accept NFT transfers
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return 0x150b7a02;
    }
}

// ============================================================
//  GringottsBank  (RING staking -> KTON rewards)
// ============================================================
contract GringottsBank is Ownable {
    uint256 public constant MONTH = 30 days;

    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 months;
        uint256 ktonMinted;
        bool    active;
    }

    address public ring;
    address public kton;
    mapping(address => Stake[]) public stakes;

    event Staked(address indexed user, uint256 id, uint256 amount, uint256 months, uint256 kton);
    event Unstaked(address indexed user, uint256 id, uint256 amount, bool early);

    constructor(address _ring, address _kton) { ring = _ring; kton = _kton; }

    function stakeRING(uint256 amount, uint256 months_) external {
        require(amount > 0 && months_ >= 1 && months_ <= 36, "bad params");
        require(ERC20Base(ring).transferFrom(msg.sender, address(this), amount), "ring failed");
        uint256 reward = amount * 67 * months_ / 197 / 10000;
        uint256 id = stakes[msg.sender].length;
        stakes[msg.sender].push(Stake(amount, block.timestamp, months_, reward, true));
        KtonToken(kton).mint(msg.sender, reward);
        emit Staked(msg.sender, id, amount, months_, reward);
    }

    function unstakeRING(uint256 id, bool earlyUnlock) external {
        Stake storage s = stakes[msg.sender][id];
        require(s.active, "not active");
        bool expired = block.timestamp >= s.startTime + s.months * MONTH;
        if (!expired) {
            require(earlyUnlock, "not expired");
            KtonToken(kton).burn(msg.sender, s.ktonMinted * 3);
        }
        uint256 amount = s.amount;
        s.active = false;
        require(ERC20Base(ring).transfer(msg.sender, amount), "ring failed");
        emit Unstaked(msg.sender, id, amount, !expired);
    }

    function getStake(address user, uint256 id) external view returns (
        uint256 amount, uint256 startTime, uint256 months, uint256 ktonMinted, bool active, bool expired
    ) {
        Stake storage s = stakes[user][id];
        return (s.amount, s.startTime, s.months, s.ktonMinted, s.active,
                block.timestamp >= s.startTime + s.months * MONTH);
    }
}

// ============================================================
//  LandResource  (mining system)
// ============================================================
contract LandResource is Ownable {
    bytes32 public constant CONTRACT_LAND_BASE =
        keccak256(abi.encodePacked("CONTRACT_LAND_BASE"));
    bytes32 public constant CONTRACT_OBJECT_OWNERSHIP =
        keccak256(abi.encodePacked("CONTRACT_OBJECT_OWNERSHIP"));
    bytes32 public constant CONTRACT_GOLD_ERC20_TOKEN =
        keccak256(abi.encodePacked("CONTRACT_GOLD_ERC20_TOKEN"));
    bytes32 public constant CONTRACT_WOOD_ERC20_TOKEN =
        keccak256(abi.encodePacked("CONTRACT_WOOD_ERC20_TOKEN"));
    bytes32 public constant CONTRACT_WATER_ERC20_TOKEN =
        keccak256(abi.encodePacked("CONTRACT_WATER_ERC20_TOKEN"));
    bytes32 public constant CONTRACT_FIRE_ERC20_TOKEN =
        keccak256(abi.encodePacked("CONTRACT_FIRE_ERC20_TOKEN"));
    bytes32 public constant CONTRACT_SOIL_ERC20_TOKEN =
        keccak256(abi.encodePacked("CONTRACT_SOIL_ERC20_TOKEN"));

    uint256 public constant BASE_RATE = 11574074074074; // 1e18/86400

    SettingsRegistry public registry;
    mapping(uint256 => uint256) public lastClaimTime;
    mapping(uint256 => uint256) public apostleCount;

    event StartMining(uint256 indexed land, uint256 indexed apostle);
    event StopMining(uint256 indexed land, uint256 indexed apostle);
    event Claimed(uint256 indexed land, address owner);

    constructor(address _registry) { registry = SettingsRegistry(_registry); }

    function startMining(uint256 landId, uint256 apostleId) external {
        _claim(landId);
        apostleCount[landId]++;
        if (lastClaimTime[landId] == 0) lastClaimTime[landId] = block.timestamp;
        emit StartMining(landId, apostleId);
    }

    function stopMining(uint256 landId, uint256 apostleId) external {
        require(apostleCount[landId] > 0, "none mining");
        _claim(landId);
        apostleCount[landId]--;
        emit StopMining(landId, apostleId);
    }

    function claimResources(uint256 landId) external { _claim(landId); }

    function _claim(uint256 landId) internal {
        uint256 count = apostleCount[landId];
        uint256 last  = lastClaimTime[landId];
        if (last == 0) { lastClaimTime[landId] = block.timestamp; return; }
        uint256 elapsed = block.timestamp - last;
        if (elapsed == 0 || count == 0) { lastClaimTime[landId] = block.timestamp; return; }

        LandBase lb = LandBase(registry.addressOf(CONTRACT_LAND_BASE));
        (uint256 attr,,,) = lb.getLandAttr(landId);
        address owner_ = ObjectOwnership(registry.addressOf(CONTRACT_OBJECT_OWNERSHIP)).ownerOf(landId);
        if (owner_ == address(0)) { lastClaimTime[landId] = block.timestamp; return; }

        _mintRes(CONTRACT_GOLD_ERC20_TOKEN,  0, attr, elapsed, count, owner_);
        _mintRes(CONTRACT_WOOD_ERC20_TOKEN,  1, attr, elapsed, count, owner_);
        _mintRes(CONTRACT_WATER_ERC20_TOKEN, 2, attr, elapsed, count, owner_);
        _mintRes(CONTRACT_FIRE_ERC20_TOKEN,  3, attr, elapsed, count, owner_);
        _mintRes(CONTRACT_SOIL_ERC20_TOKEN,  4, attr, elapsed, count, owner_);
        lastClaimTime[landId] = block.timestamp;
        emit Claimed(landId, owner_);
    }

    function _mintRes(bytes32 key, uint8 idx, uint256 attr, uint256 elapsed, uint256 count, address to) internal {
        uint16 rate = uint16((attr >> (uint256(idx) * 16)) & 0xFFFF);
        if (rate == 0) return;
        uint256 amt = uint256(rate) * elapsed * BASE_RATE * count / 1e12;
        if (amt == 0) return;
        address tok = registry.addressOf(key);
        if (tok != address(0)) ResourceToken(tok).mint(to, amt);
    }

    function available(uint256 landId) external view returns (uint256[5] memory res) {
        uint256 count = apostleCount[landId];
        uint256 last  = lastClaimTime[landId];
        if (last == 0 || count == 0) return res;
        uint256 elapsed = block.timestamp - last;
        LandBase lb = LandBase(registry.addressOf(CONTRACT_LAND_BASE));
        (uint256 attr,,,) = lb.getLandAttr(landId);
        for (uint8 i = 0; i < 5; i++) {
            uint16 rate = uint16((attr >> (uint256(i) * 16)) & 0xFFFF);
            if (rate == 0) continue;
            res[i] = uint256(rate) * elapsed * BASE_RATE * count / 1e12;
        }
    }
}
