// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// =============================================================
//  Evolution Land BSC  —  Simplified Single-Chain Edition
//
//  Tokens:   RING (main) + GOLD / WOOD / HHO / FIRE / SIOO
//  NFTs:     Land (100x100) + Drill + Apostle
//  Systems:  Mining (Apostle works on Land, Drill boosts rate)
//            Dutch Auction (Land primary sale)
// =============================================================

// ── Helpers ──────────────────────────────────────────────────

abstract contract Ownable {
    address public owner;
    event OwnershipTransferred(address indexed prev, address indexed next);
    constructor() { owner = msg.sender; }
    modifier onlyOwner() { require(msg.sender == owner, "!owner"); _; }
    function transferOwnership(address a) external onlyOwner {
        require(a != address(0)); emit OwnershipTransferred(owner, a); owner = a;
    }
}

abstract contract ERC20Base {
    string  public name;
    string  public symbol;
    uint8   public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    event Transfer(address indexed f, address indexed t, uint256 v);
    event Approval(address indexed o, address indexed s, uint256 v);
    constructor(string memory n, string memory s) { name = n; symbol = s; }
    function transfer(address t, uint256 v) external returns (bool) { _transfer(msg.sender,t,v); return true; }
    function approve(address s, uint256 v) external returns (bool) { allowance[msg.sender][s]=v; emit Approval(msg.sender,s,v); return true; }
    function transferFrom(address f, address t, uint256 v) external returns (bool) {
        if (allowance[f][msg.sender] != type(uint256).max) allowance[f][msg.sender] -= v;
        _transfer(f,t,v); return true;
    }
    function _transfer(address f, address t, uint256 v) internal { require(t!=address(0)); balanceOf[f]-=v; balanceOf[t]+=v; emit Transfer(f,t,v); }
    function _mint(address t, uint256 v) internal { totalSupply+=v; balanceOf[t]+=v; emit Transfer(address(0),t,v); }
    function _burn(address f, uint256 v) internal { balanceOf[f]-=v; totalSupply-=v; emit Transfer(f,address(0),v); }
}

abstract contract MintableERC20 is ERC20Base, Ownable {
    mapping(address => bool) public minters;
    constructor(string memory n, string memory s) ERC20Base(n,s) {}
    modifier onlyMinter() { require(minters[msg.sender]||msg.sender==owner,"!minter"); _; }
    function setMinter(address a, bool v) external onlyOwner { minters[a]=v; }
    function mint(address t, uint256 v) external onlyMinter { _mint(t,v); }
    function burn(address f, uint256 v) external onlyMinter { _burn(f,v); }
}

interface IERC721Receiver {
    function onERC721Received(address,address,uint256,bytes calldata) external returns (bytes4);
}

abstract contract ERC721Base is Ownable {
    string public name; string public symbol;
    mapping(uint256=>address) public ownerOf;
    mapping(address=>uint256) public balanceOf;
    mapping(uint256=>address) public getApproved;
    mapping(address=>mapping(address=>bool)) public isApprovedForAll;
    event Transfer(address indexed f, address indexed t, uint256 indexed id);
    event Approval(address indexed o, address indexed a, uint256 indexed id);
    event ApprovalForAll(address indexed o, address indexed op, bool v);
    constructor(string memory n, string memory s) { name=n; symbol=s; }
    function supportsInterface(bytes4 id) external pure returns(bool) {
        return id==0x80ac58cd||id==0x5b5e139f||id==0x01ffc9a7;
    }
    function approve(address a, uint256 id) external {
        address o=ownerOf[id]; require(msg.sender==o||isApprovedForAll[o][msg.sender]);
        getApproved[id]=a; emit Approval(o,a,id);
    }
    function setApprovalForAll(address op, bool v) external { isApprovedForAll[msg.sender][op]=v; emit ApprovalForAll(msg.sender,op,v); }
    function transferFrom(address f, address t, uint256 id) public virtual {
        require(_ok(msg.sender,id)); _xfer(f,t,id);
    }
    function safeTransferFrom(address f, address t, uint256 id) external { safeTransferFrom(f,t,id,""); }
    function safeTransferFrom(address f, address t, uint256 id, bytes memory d) public virtual {
        require(_ok(msg.sender,id)); _xfer(f,t,id); _chk(msg.sender,f,t,id,d);
    }
    function _ok(address s, uint256 id) internal view returns(bool) {
        address o=ownerOf[id]; return s==o||isApprovedForAll[o][s]||getApproved[id]==s;
    }
    function _xfer(address f, address t, uint256 id) internal {
        require(ownerOf[id]==f&&t!=address(0)); delete getApproved[id];
        balanceOf[f]--; balanceOf[t]++; ownerOf[id]=t; emit Transfer(f,t,id);
    }
    function _mint(address t, uint256 id) internal {
        require(t!=address(0)&&ownerOf[id]==address(0)); balanceOf[t]++; ownerOf[id]=t; emit Transfer(address(0),t,id);
    }
    function _burn(uint256 id) internal {
        address o=ownerOf[id]; require(o!=address(0)); balanceOf[o]--; delete ownerOf[id]; delete getApproved[id]; emit Transfer(o,address(0),id);
    }
    function _chk(address op, address f, address t, uint256 id, bytes memory d) internal {
        if (t.code.length>0) require(IERC721Receiver(t).onERC721Received(op,f,id,d)==0x150b7a02,"!receiver");
    }
}

// ── Tokens ───────────────────────────────────────────────────

/// @notice RING — main game currency. 10,000 pre-minted to deployer.
contract RingToken is MintableERC20 {
    constructor() MintableERC20("Evolution Land Ring", "RING") {
        _mint(msg.sender, 10_000 * 1e18);
    }
}

contract GoldToken  is MintableERC20 { constructor() MintableERC20("EvoLand Gold",  "GOLD") {} }
contract WoodToken  is MintableERC20 { constructor() MintableERC20("EvoLand Wood",  "WOOD") {} }
contract WaterToken is MintableERC20 { constructor() MintableERC20("EvoLand Water", "HHO")  {} }
contract FireToken  is MintableERC20 { constructor() MintableERC20("EvoLand Fire",  "FIRE") {} }
contract SoilToken  is MintableERC20 { constructor() MintableERC20("EvoLand Soil",  "SIOO") {} }

// ── NFTs ─────────────────────────────────────────────────────

/**
 * @notice LandNFT — 10,000 parcels (x 0-99, y 0-99)
 *   tokenId = x * 100 + y + 1  (1-based, range 1-10000)
 *   resourceAttr: packed uint80  [gold:16][wood:16][water:16][fire:16][soil:16]
 *     each field is the land's base mining rate (1-1000 units/day per apostle)
 */
contract LandNFT is ERC721Base {
    mapping(address => bool) public operators;
    // resourceAttr packed: bits 0-15=gold, 16-31=wood, 32-47=water, 48-63=fire, 64-79=soil
    mapping(uint256 => uint80) public resourceAttr;
    // district tag (future use, default 1)
    mapping(uint256 => uint8)  public district;

    event LandMinted(uint256 indexed tokenId, int16 x, int16 y, uint80 attr);

    modifier onlyOperator() { require(operators[msg.sender]||msg.sender==owner,"!op"); _; }

    constructor() ERC721Base("Evolution Land", "LAND") {}

    function setOperator(address a, bool v) external onlyOwner { operators[a]=v; }

    function encodeId(int16 x, int16 y) public pure returns (uint256) {
        require(x>=0&&x<=99&&y>=0&&y<=99,"oob");
        return uint256(uint16(x))*100 + uint256(uint16(y)) + 1;
    }
    function decodeId(uint256 id) public pure returns (int16 x, int16 y) {
        uint256 idx = id - 1;
        x = int16(int256(idx/100)); y = int16(int256(idx%100));
    }

    function mint(address to, int16 x, int16 y, uint80 attr) external onlyOperator {
        uint256 id = encodeId(x,y);
        resourceAttr[id] = attr; district[id] = 1;
        _mint(to, id);
        emit LandMinted(id, x, y, attr);
    }

    // Operator can transfer without per-token approval (auction contract)
    function transferFrom(address f, address t, uint256 id) public override {
        if (operators[msg.sender]) _xfer(f,t,id);
        else super.transferFrom(f,t,id);
    }
    function safeTransferFrom(address f, address t, uint256 id, bytes memory d) public override {
        if (operators[msg.sender]) { _xfer(f,t,id); _chk(msg.sender,f,t,id,d); }
        else super.safeTransferFrom(f,t,id,d);
    }

    // Decode rate for a single resource (0=gold,1=wood,2=water,3=fire,4=soil)
    function getRate(uint256 id, uint8 res) public view returns (uint16) {
        return uint16(resourceAttr[id] >> (uint256(res)*16));
    }
}

/**
 * @notice DrillNFT — equipment NFT that boosts mining rate when equipped on land
 *   tier 1-5:  boost multiplier = tier * 20%  (tier5 = 2x)
 *   resource affinity: which resource it boosts (0-4)
 */
contract DrillNFT is ERC721Base {
    uint256 public nextId = 1;
    mapping(address => bool) public operators;

    struct DrillAttr { uint8 tier; uint8 affinity; } // affinity: 0=gold,1=wood,2=water,3=fire,4=soil
    mapping(uint256 => DrillAttr) public attrs;

    event DrillMinted(uint256 indexed id, address to, uint8 tier, uint8 affinity);

    modifier onlyOperator() { require(operators[msg.sender]||msg.sender==owner,"!op"); _; }

    constructor() ERC721Base("EvoLand Drill", "DRILL") {}

    function setOperator(address a, bool v) external onlyOwner { operators[a]=v; }

    function mint(address to, uint8 tier, uint8 affinity) external onlyOperator returns (uint256 id) {
        require(tier>=1&&tier<=5&&affinity<=4,"bad attr");
        id = nextId++;
        attrs[id] = DrillAttr(tier, affinity);
        _mint(to, id);
        emit DrillMinted(id, to, tier, affinity);
    }

    function transferFrom(address f, address t, uint256 id) public override {
        if (operators[msg.sender]) _xfer(f,t,id);
        else super.transferFrom(f,t,id);
    }
    function safeTransferFrom(address f, address t, uint256 id, bytes memory d) public override {
        if (operators[msg.sender]) { _xfer(f,t,id); _chk(msg.sender,f,t,id,d); }
        else super.safeTransferFrom(f,t,id,d);
    }
}

/**
 * @notice ApostleNFT — worker NFT sent to mine on lands
 *   strength 1-100: affects mining output
 *   Apostles are minted by the game owner (or via a future breeding system)
 */
contract ApostleNFT is ERC721Base {
    uint256 public nextId = 1;
    mapping(address => bool) public operators;

    struct ApostleAttr { uint8 strength; uint8 element; } // element: 0-4 affinity
    mapping(uint256 => ApostleAttr) public attrs;

    event ApostleMinted(uint256 indexed id, address to, uint8 strength, uint8 element);

    modifier onlyOperator() { require(operators[msg.sender]||msg.sender==owner,"!op"); _; }

    constructor() ERC721Base("EvoLand Apostle", "APO") {}

    function setOperator(address a, bool v) external onlyOwner { operators[a]=v; }

    function mint(address to, uint8 strength, uint8 element) external onlyOperator returns (uint256 id) {
        require(strength>=1&&strength<=100&&element<=4,"bad attr");
        id = nextId++;
        attrs[id] = ApostleAttr(strength, element);
        _mint(to, id);
        emit ApostleMinted(id, to, strength, element);
    }

    function transferFrom(address f, address t, uint256 id) public override {
        if (operators[msg.sender]) _xfer(f,t,id);
        else super.transferFrom(f,t,id);
    }
    function safeTransferFrom(address f, address t, uint256 id, bytes memory d) public override {
        if (operators[msg.sender]) { _xfer(f,t,id); _chk(msg.sender,f,t,id,d); }
        else super.safeTransferFrom(f,t,id,d);
    }
}

// ── Mining System ─────────────────────────────────────────────

/**
 * @notice MiningSystem — core gameplay loop
 *
 *   Flow:
 *     1. Land owner calls startMining(landId, apostleId, drillId)  [drillId=0 = no drill]
 *     2. Resources accrue per second based on land rates + apostle strength + drill boost
 *     3. Anyone calls claim(landId) to mint accrued resources to land owner
 *     4. Land owner calls stopMining(landId, apostleId) to retrieve apostle
 *
 *   Formula (per second, per apostle slot):
 *     output = landRate * apostleStrength/50 * drillMultiplier / 86400
 *     drillMultiplier = 1.0 + tier*0.2  if drill affinity matches resource, else 1.0
 *
 *   Multiple apostles can work the same land (up to MAX_APOSTLES_PER_LAND = 5)
 */
contract MiningSystem is Ownable {
    uint256 public constant MAX_APOSTLES_PER_LAND = 5;
    uint256 public constant PRECISION = 1e12; // avoid truncation

    LandNFT    public land;
    DrillNFT   public drill;
    ApostleNFT public apostle;

    address[5] public resources; // [gold, wood, water, fire, soil]

    struct Slot {
        uint256 apostleId;
        uint256 drillId;    // 0 = no drill
        uint256 startTime;
    }
    // landId => list of active slots
    mapping(uint256 => Slot[MAX_APOSTLES_PER_LAND]) public slots;
    mapping(uint256 => uint256) public slotCount;

    // Track which apostle / drill is locked
    mapping(uint256 => uint256) public apostleOnLand; // apostleId => landId (0=free)
    mapping(uint256 => uint256) public drillOnLand;   // drillId   => landId (0=free)

    // Unclaimed balance per resource per land (accumulated before claim)
    mapping(uint256 => uint256[5]) public pending;
    uint256 public lastUpdate; // timestamp of last global flush (unused — per-slot tracking)

    event MiningStarted(uint256 indexed landId, uint256 apostleId, uint256 drillId);
    event MiningStopped(uint256 indexed landId, uint256 apostleId);
    event Claimed(uint256 indexed landId, address indexed owner, uint256[5] amounts);

    constructor(
        address _land, address _drill, address _apostle,
        address[5] memory _resources
    ) {
        land     = LandNFT(_land);
        drill    = DrillNFT(_drill);
        apostle  = ApostleNFT(_apostle);
        resources = _resources;
    }

    // ── Start Mining ─────────────────────────────────────────
    function startMining(uint256 landId, uint256 apostleId, uint256 drillId) external {
        require(land.ownerOf(landId) == msg.sender, "!land owner");
        require(apostle.ownerOf(apostleId) == msg.sender, "!apostle owner");
        require(apostleOnLand[apostleId] == 0, "apostle busy");
        uint256 count = slotCount[landId];
        require(count < MAX_APOSTLES_PER_LAND, "land full");

        if (drillId != 0) {
            require(drill.ownerOf(drillId) == msg.sender, "!drill owner");
            require(drillOnLand[drillId] == 0, "drill busy");
            // Transfer drill to this contract as escrow
            drill.transferFrom(msg.sender, address(this), drillId);
            drillOnLand[drillId] = landId;
        }
        // Transfer apostle to this contract as escrow
        apostle.transferFrom(msg.sender, address(this), apostleId);
        apostleOnLand[apostleId] = landId;

        slots[landId][count] = Slot(apostleId, drillId, block.timestamp);
        slotCount[landId] = count + 1;

        emit MiningStarted(landId, apostleId, drillId);
    }

    // ── Stop Mining ──────────────────────────────────────────
    function stopMining(uint256 landId, uint256 apostleId) external {
        require(land.ownerOf(landId) == msg.sender, "!land owner");
        _flushLand(landId);

        uint256 count = slotCount[landId];
        bool found = false;
        for (uint256 i = 0; i < count; i++) {
            if (slots[landId][i].apostleId == apostleId) {
                uint256 drillId = slots[landId][i].drillId;
                // Return NFTs
                apostle.transferFrom(address(this), msg.sender, apostleId);
                apostleOnLand[apostleId] = 0;
                if (drillId != 0) {
                    drill.transferFrom(address(this), msg.sender, drillId);
                    drillOnLand[drillId] = 0;
                }
                // Compact slot array
                slots[landId][i] = slots[landId][count-1];
                delete slots[landId][count-1];
                slotCount[landId] = count - 1;
                found = true;
                break;
            }
        }
        require(found, "apostle not here");
        emit MiningStopped(landId, apostleId);
    }

    // ── Claim ────────────────────────────────────────────────
    function claim(uint256 landId) external {
        _flushLand(landId);
        address owner = land.ownerOf(landId);
        uint256[5] memory amounts;
        for (uint8 r = 0; r < 5; r++) {
            uint256 amt = pending[landId][r];
            if (amt > 0) {
                pending[landId][r] = 0;
                amounts[r] = amt;
                MintableERC20(resources[r]).mint(owner, amt);
            }
        }
        emit Claimed(landId, owner, amounts);
    }

    // ── View: how much is available to claim ─────────────────
    function pendingRewards(uint256 landId) external view returns (uint256[5] memory res) {
        for (uint8 r = 0; r < 5; r++) res[r] = pending[landId][r];
        uint256 count = slotCount[landId];
        for (uint256 i = 0; i < count; i++) {
            Slot storage s = slots[landId][i];
            uint256 elapsed = block.timestamp - s.startTime;
            uint256[5] memory inc = _calcIncrement(landId, s, elapsed);
            for (uint8 r = 0; r < 5; r++) res[r] += inc[r];
        }
    }

    // ── Internal ─────────────────────────────────────────────
    function _flushLand(uint256 landId) internal {
        uint256 count = slotCount[landId];
        for (uint256 i = 0; i < count; i++) {
            Slot storage s = slots[landId][i];
            uint256 elapsed = block.timestamp - s.startTime;
            if (elapsed == 0) continue;
            uint256[5] memory inc = _calcIncrement(landId, s, elapsed);
            for (uint8 r = 0; r < 5; r++) pending[landId][r] += inc[r];
            s.startTime = block.timestamp; // reset timer
        }
    }

    function _calcIncrement(uint256 landId, Slot storage s, uint256 elapsed)
        internal view returns (uint256[5] memory inc)
    {
        ApostleNFT.ApostleAttr memory aa = _getApostleAttr(s.apostleId);
        DrillNFT.DrillAttr memory da;
        bool hasDrill = s.drillId != 0;
        if (hasDrill) da = _getDrillAttr(s.drillId);

        for (uint8 r = 0; r < 5; r++) {
            uint256 rate = land.getRate(landId, r); // base rate (units/day)
            if (rate == 0) continue;
            // apostle strength factor:  strength/50  (strength=50 → 1x)
            uint256 strength = aa.strength; // 1-100
            // drill boost: +tier*20% if affinity matches
            uint256 boost = 100; // 100% base
            if (hasDrill && da.affinity == r) boost += uint256(da.tier) * 20;
            // output = rate * strength * boost * elapsed / (50 * 100 * 86400)
            inc[r] = rate * 1e18 * strength * boost * elapsed / (50 * 100 * 86400 * PRECISION);
        }
    }

    // Work around stack-too-deep for struct reads
    function _getApostleAttr(uint256 id) internal view returns (ApostleNFT.ApostleAttr memory) {
        (uint8 s, uint8 e) = apostle.attrs(id);
        return ApostleNFT.ApostleAttr(s, e);
    }
    function _getDrillAttr(uint256 id) internal view returns (DrillNFT.DrillAttr memory) {
        (uint8 t, uint8 a) = drill.attrs(id);
        return DrillNFT.DrillAttr(t, a);
    }

    // ERC721 receiver (to hold escrowed apostles/drills)
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return 0x150b7a02;
    }
}

// ── Dutch Auction (Land primary sale) ────────────────────────

/**
 * @notice LandAuction — Dutch auction for land parcels
 *   Seller lists a land, price linearly drops from startPrice to endPrice over duration.
 *   Buyer pays RING. 4% fee kept by contract owner.
 */
contract LandAuction is Ownable {
    uint256 public constant FEE_BPS = 400;   // 4%
    uint256 public constant BPS     = 10000;

    LandNFT  public land;
    address  public ring;

    struct Auction {
        address seller;
        uint128 startPrice;
        uint128 endPrice;
        uint64  duration;
        uint64  startedAt;
    }
    mapping(uint256 => Auction) public auctions;
    bool private _lock;

    event AuctionCreated(uint256 indexed id, address seller, uint128 start, uint128 end, uint64 duration);
    event AuctionWon(uint256 indexed id, address buyer, uint256 price);
    event AuctionCancelled(uint256 indexed id);

    modifier noReentrant() { require(!_lock); _lock=true; _; _lock=false; }

    constructor(address _land, address _ring) { land=LandNFT(_land); ring=_ring; }

    function createAuction(uint256 id, uint128 startPrice, uint128 endPrice, uint64 duration) external noReentrant {
        require(land.ownerOf(id)==msg.sender,"!owner");
        require(duration>=60&&duration<=30 days);
        require(startPrice>=endPrice);
        land.transferFrom(msg.sender, address(this), id);
        auctions[id] = Auction(msg.sender, startPrice, endPrice, duration, uint64(block.timestamp));
        emit AuctionCreated(id, msg.sender, startPrice, endPrice, duration);
    }

    function bid(uint256 id, uint256 maxPay) external noReentrant {
        Auction storage a = auctions[id];
        require(a.startedAt>0,"no auction");
        uint256 price = currentPrice(id);
        require(maxPay>=price,"too low");
        uint256 fee = price*FEE_BPS/BPS;
        ERC20Base r = ERC20Base(ring);
        require(r.transferFrom(msg.sender, a.seller, price-fee),"ring fail");
        if (fee>0) r.transferFrom(msg.sender, owner, fee);
        address seller = a.seller;
        delete auctions[id];
        land.transferFrom(address(this), msg.sender, id);
        emit AuctionWon(id, msg.sender, price);
    }

    function cancelAuction(uint256 id) external noReentrant {
        Auction storage a = auctions[id];
        require(a.startedAt>0);
        require(a.seller==msg.sender||msg.sender==owner);
        address seller = a.seller;
        delete auctions[id];
        land.transferFrom(address(this), seller, id);
        emit AuctionCancelled(id);
    }

    function currentPrice(uint256 id) public view returns (uint256) {
        Auction storage a = auctions[id];
        require(a.startedAt>0);
        uint256 elapsed = block.timestamp - a.startedAt;
        if (elapsed>=a.duration) return a.endPrice;
        uint256 diff = a.startPrice - a.endPrice;
        return a.startPrice - diff*elapsed/a.duration;
    }

    function onERC721Received(address,address,uint256,bytes calldata) external pure returns (bytes4) {
        return 0x150b7a02;
    }
}

// ── LandInitializer (batch-mint 10000 lands) ──────────────────

/**
 * @notice LandInitializer — owner utility to batch-mint lands and start genesis auctions.
 *         Can be called after deployment, then ownership can be revoked.
 */
contract LandInitializer is Ownable {
    LandNFT     public land;
    LandAuction public auction;
    address     public ring;
    bool        public initialized;

    constructor(address _land, address _auction, address _ring) {
        land=LandNFT(_land); auction=LandAuction(_auction); ring=_ring;
    }

    function batchMint(
        int16[] calldata xs,
        int16[] calldata ys,
        uint80[] calldata attrs,
        address to
    ) external onlyOwner {
        for (uint256 i=0; i<xs.length; i++) {
            land.mint(to, xs[i], ys[i], attrs[i]);
        }
    }

    function createGenesisAuctions(
        uint256[] calldata ids,
        uint128 startPrice,
        uint128 endPrice,
        uint64  duration
    ) external onlyOwner {
        // approve auction contract to transfer
        // (deployer must have called land.setOperator(initializer, true))
        for (uint256 i=0; i<ids.length; i++) {
            try auction.createAuction(ids[i], startPrice, endPrice, duration) {}
            catch {}
        }
    }
}
