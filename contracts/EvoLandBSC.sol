// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// =============================================================
//  Evolution Land BSC  —  Simplified Single-Chain Edition
//  v2: ApostleNFT 升级 — 基因/成长/繁殖系统完整实现
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
 */
contract LandNFT is ERC721Base {
    mapping(address => bool) public operators;
    mapping(uint256 => uint80) public resourceAttr;
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

    function transferFrom(address f, address t, uint256 id) public override {
        if (operators[msg.sender]) _xfer(f,t,id);
        else super.transferFrom(f,t,id);
    }
    function safeTransferFrom(address f, address t, uint256 id, bytes memory d) public override {
        if (operators[msg.sender]) { _xfer(f,t,id); _chk(msg.sender,f,t,id,d); }
        else super.safeTransferFrom(f,t,id,d);
    }

    function getRate(uint256 id, uint8 res) public view returns (uint16) {
        return uint16(resourceAttr[id] >> (uint256(res)*16));
    }
}

/**
 * @notice DrillNFT — equipment NFT
 */
contract DrillNFT is ERC721Base {
    uint256 public nextId = 1;
    mapping(address => bool) public operators;

    struct DrillAttr { uint8 tier; uint8 affinity; }
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
 * @notice ApostleNFT v2 — 完整基因/成长/繁殖系统
 *
 *  基因（genes, uint256）编码方式兼容 Evolution Land 原版：
 *    bit 241      = gender  (0=female, 1=male)
 *    bits 242-243 = race    (0=human)
 *    其余位       = 外貌/才能随机特征
 *
 *  成长：mint 后 GROW_PERIOD (7天) 内为幼体，之后自动成年
 *  繁殖：雄+雌，双方均已成年，冷却期结束后可繁殖，消耗 RING
 *  tokenURI：返回 https://api.evolution.land/apostle/{genes}.png
 */
contract ApostleNFT is ERC721Base {
    uint256 public constant GROW_PERIOD    = 7 days;
    uint256 public constant BASE_COOLDOWN  = 1 days;  // 第0代冷却
    uint256 public nextId = 1;

    mapping(address => bool) public operators;

    // ── 核心属性 ─────────────────────────────────────────────
    struct ApostleAttr {
        uint8   strength;   // 1-100 挖矿力
        uint8   element;    // 0-4   元素亲和
        uint8   gender;     // 0=female 1=male
        uint16  gen;        // 代数 0=创世
        uint256 genes;      // 256位基因，与原版兼容
        uint64  birthTime;  // mint 时间戳
        uint64  cooldownEnd;// 繁殖冷却结束时间
        uint32  motherId;   // 0=无
        uint32  fatherId;   // 0=无
    }
    mapping(uint256 => ApostleAttr) public attrs;

    // ── 繁殖费 ───────────────────────────────────────────────
    address public ring;            // RING token
    uint256 public breedFee = 1e18; // 1 RING per breed

    // ── Events ───────────────────────────────────────────────
    event ApostleMinted(uint256 indexed id, address to, uint8 strength, uint8 element, uint8 gender, uint256 genes);
    event ApostleBorn(uint256 indexed id, address to, uint32 motherId, uint32 fatherId, uint256 genes);

    modifier onlyOperator() { require(operators[msg.sender]||msg.sender==owner,"!op"); _; }

    constructor(address _ring) ERC721Base("EvoLand Apostle", "APO") {
        ring = _ring;
    }

    function setOperator(address a, bool v) external onlyOwner { operators[a]=v; }
    function setBreedFee(uint256 f) external onlyOwner { breedFee = f; }
    function setRing(address r) external onlyOwner { ring = r; }

    // ── Mint (由 BlindBox 或 owner 调用) ────────────────────
    /// @param to        接收者
    /// @param strength  力量 1-100
    /// @param element   元素 0-4
    /// @param genes     256位基因（BlindBox 随机生成）
    function mint(address to, uint8 strength, uint8 element, uint256 genes)
        external onlyOperator returns (uint256 id)
    {
        require(strength>=1&&strength<=100&&element<=4,"bad attr");
        uint8 gender = uint8((genes >> 241) & 1); // 从基因提取性别
        id = nextId++;
        attrs[id] = ApostleAttr({
            strength:    strength,
            element:     element,
            gender:      gender,
            gen:         0,
            genes:       genes,
            birthTime:   uint64(block.timestamp),
            cooldownEnd: 0,
            motherId:    0,
            fatherId:    0
        });
        _mint(to, id);
        emit ApostleMinted(id, to, strength, element, gender, genes);
    }

    // ── 成年判断 ─────────────────────────────────────────────
    function isAdult(uint256 id) public view returns (bool) {
        return block.timestamp >= uint256(attrs[id].birthTime) + GROW_PERIOD;
    }

    /// @return 0-100 的成长进度百分比
    function growthProgress(uint256 id) public view returns (uint8) {
        uint256 born = attrs[id].birthTime;
        if (born == 0) return 0;
        uint256 elapsed = block.timestamp - born;
        if (elapsed >= GROW_PERIOD) return 100;
        return uint8(elapsed * 100 / GROW_PERIOD);
    }

    // ── tokenURI — 返回原版 Evolution Land 使徒图片 ─────────
    function tokenURI(uint256 id) external view returns (string memory) {
        require(ownerOf[id] != address(0), "!exist");
        uint256 genes = attrs[id].genes;
        // 与原版完全一致: https://api.evolution.land/apostle/{genesU256}.png
        return string(abi.encodePacked(
            "https://api.evolution.land/apostle/",
            _toString(genes),
            ".png"
        ));
    }

    // ── 繁殖 ─────────────────────────────────────────────────
    /// @param maleId   雄性使徒 ID
    /// @param femaleId 雌性使徒 ID
    /// @return childId 新生使徒 ID
    function breed(uint256 maleId, uint256 femaleId) external returns (uint256 childId) {
        ApostleAttr storage m = attrs[maleId];
        ApostleAttr storage f = attrs[femaleId];

        require(ownerOf[maleId]   == msg.sender, "!male owner");
        require(ownerOf[femaleId] == msg.sender, "!female owner");
        require(m.gender == 1, "!male");
        require(f.gender == 0, "!female");
        require(isAdult(maleId),   "male not adult");
        require(isAdult(femaleId), "female not adult");
        require(block.timestamp >= m.cooldownEnd, "male cooling");
        require(block.timestamp >= f.cooldownEnd, "female cooling");

        // 收取繁殖费
        if (breedFee > 0 && ring != address(0)) {
            require(
                MintableERC20(ring).transferFrom(msg.sender, owner, breedFee),
                "breed fee failed"
            );
        }

        // 生成后代基因（混合双亲基因 + 随机变异）
        uint256 seed = uint256(keccak256(abi.encodePacked(
            block.prevrandao, block.timestamp, msg.sender, maleId, femaleId, nextId
        )));
        uint256 childGenes = _mixGenes(m.genes, f.genes, seed);
        uint8 childGender  = uint8((childGenes >> 241) & 1);

        // 后代力量：双亲均值 ± 随机浮动
        uint8 childStrength;
        {
            uint256 avg = (uint256(m.strength) + uint256(f.strength)) / 2;
            int256 delta = int256(seed & 0x1f) - 16; // -16 ~ +15
            int256 s = int256(avg) + delta;
            if (s < 1) s = 1;
            if (s > 100) s = 100;
            childStrength = uint8(uint256(s));
        }

        // 后代元素：随机取父或母
        uint8 childElem = ((seed >> 8) & 1) == 0 ? m.element : f.element;

        // 后代代数
        uint16 childGen = m.gen > f.gen ? m.gen + 1 : f.gen + 1;

        // 更新冷却
        uint256 cd = BASE_COOLDOWN * (1 << uint256(m.gen));
        if (cd > 30 days) cd = 30 days;
        m.cooldownEnd = uint64(block.timestamp + cd);

        cd = BASE_COOLDOWN * (1 << uint256(f.gen));
        if (cd > 30 days) cd = 30 days;
        f.cooldownEnd = uint64(block.timestamp + cd);

        // 铸造后代
        childId = nextId++;
        attrs[childId] = ApostleAttr({
            strength:    childStrength,
            element:     childElem,
            gender:      childGender,
            gen:         childGen,
            genes:       childGenes,
            birthTime:   uint64(block.timestamp),
            cooldownEnd: 0,
            motherId:    uint32(femaleId),
            fatherId:    uint32(maleId)
        });
        _mint(msg.sender, childId);
        emit ApostleBorn(childId, msg.sender, uint32(femaleId), uint32(maleId), childGenes);
    }

    // ── 基因混合算法（兼容原版逻辑简化版）───────────────────
    function _mixGenes(uint256 a, uint256 b, uint256 seed) internal pure returns (uint256 child) {
        // 按 256 bit 分 8 段，每段随机选父或母，末位随机变异
        for (uint8 i = 0; i < 8; i++) {
            uint256 mask = type(uint256).max >> (256 - 32) << (i * 32);
            bool useFather = (seed >> i) & 1 == 1;
            uint256 segment = useFather ? (a & mask) : (b & mask);
            // 1% 概率对该段随机变异
            if ((seed >> (i + 8)) % 100 == 0) {
                segment = (seed << (i * 32)) & mask;
            }
            child |= segment;
        }
        // gender bit (241) 随机
        if ((seed >> 20) & 1 == 1) child |= (uint256(1) << 241);
        else child &= ~(uint256(1) << 241);
    }

    // ── 工具 ─────────────────────────────────────────────────
    function _toString(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 tmp = v; uint256 len;
        while (tmp != 0) { len++; tmp /= 10; }
        bytes memory buf = new bytes(len);
        while (v != 0) { buf[--len] = bytes1(uint8(48 + v % 10)); v /= 10; }
        return string(buf);
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

contract MiningSystem is Ownable {
    uint256 public constant MAX_APOSTLES_PER_LAND = 5;
    uint256 public constant PRECISION = 1e12;

    LandNFT    public land;
    DrillNFT   public drill;
    ApostleNFT public apostle;

    address[5] public resources;

    struct Slot {
        uint256 apostleId;
        uint256 drillId;
        uint256 startTime;
    }
    mapping(uint256 => Slot[MAX_APOSTLES_PER_LAND]) public slots;
    mapping(uint256 => uint256) public slotCount;
    mapping(uint256 => uint256) public apostleOnLand;
    mapping(uint256 => uint256) public drillOnLand;
    mapping(uint256 => uint256[5]) public pending;
    uint256 public lastUpdate;

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

    function startMining(uint256 landId, uint256 apostleId, uint256 drillId) external {
        require(land.ownerOf(landId) == msg.sender, "!land owner");
        require(apostle.ownerOf(apostleId) == msg.sender, "!apostle owner");
        require(apostle.isAdult(apostleId), "apostle not adult");
        require(apostleOnLand[apostleId] == 0, "apostle busy");
        uint256 count = slotCount[landId];
        require(count < MAX_APOSTLES_PER_LAND, "land full");

        if (drillId != 0) {
            require(drill.ownerOf(drillId) == msg.sender, "!drill owner");
            require(drillOnLand[drillId] == 0, "drill busy");
            drill.transferFrom(msg.sender, address(this), drillId);
            drillOnLand[drillId] = landId;
        }
        apostle.transferFrom(msg.sender, address(this), apostleId);
        apostleOnLand[apostleId] = landId;

        slots[landId][count] = Slot(apostleId, drillId, block.timestamp);
        slotCount[landId] = count + 1;

        emit MiningStarted(landId, apostleId, drillId);
    }

    function stopMining(uint256 landId, uint256 apostleId) external {
        require(land.ownerOf(landId) == msg.sender, "!land owner");
        _flushLand(landId);

        uint256 count = slotCount[landId];
        bool found = false;
        for (uint256 i = 0; i < count; i++) {
            if (slots[landId][i].apostleId == apostleId) {
                uint256 drillId = slots[landId][i].drillId;
                apostle.transferFrom(address(this), msg.sender, apostleId);
                apostleOnLand[apostleId] = 0;
                if (drillId != 0) {
                    drill.transferFrom(address(this), msg.sender, drillId);
                    drillOnLand[drillId] = 0;
                }
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

    function claim(uint256 landId) external {
        _flushLand(landId);
        address landOwner = land.ownerOf(landId);
        uint256[5] memory amounts;
        for (uint8 r = 0; r < 5; r++) {
            uint256 amt = pending[landId][r];
            if (amt > 0) {
                pending[landId][r] = 0;
                amounts[r] = amt;
                MintableERC20(resources[r]).mint(landOwner, amt);
            }
        }
        emit Claimed(landId, landOwner, amounts);
    }

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

    function _flushLand(uint256 landId) internal {
        uint256 count = slotCount[landId];
        for (uint256 i = 0; i < count; i++) {
            Slot storage s = slots[landId][i];
            uint256 elapsed = block.timestamp - s.startTime;
            if (elapsed == 0) continue;
            uint256[5] memory inc = _calcIncrement(landId, s, elapsed);
            for (uint8 r = 0; r < 5; r++) pending[landId][r] += inc[r];
            s.startTime = block.timestamp;
        }
    }

    function _calcIncrement(uint256 landId, Slot storage s, uint256 elapsed)
        internal view returns (uint256[5] memory inc)
    {
        (uint8 strength, , , , , , , ,) = _getApostleAttrs(s.apostleId);
        DrillNFT.DrillAttr memory da;
        bool hasDrill = s.drillId != 0;
        if (hasDrill) { (uint8 t, uint8 a) = drill.attrs(s.drillId); da = DrillNFT.DrillAttr(t, a); }

        for (uint8 r = 0; r < 5; r++) {
            uint256 rate = land.getRate(landId, r);
            if (rate == 0) continue;
            uint256 boost = 100;
            if (hasDrill && da.affinity == r) boost += uint256(da.tier) * 20;
            inc[r] = rate * 1e18 * uint256(strength) * boost * elapsed / (50 * 100 * 86400 * PRECISION);
        }
    }

    function _getApostleAttrs(uint256 id) internal view returns (
        uint8 strength, uint8 element, uint8 gender, uint16 gen,
        uint256 genes, uint64 birthTime, uint64 cooldownEnd,
        uint32 motherId, uint32 fatherId
    ) {
        ApostleNFT.ApostleAttr memory a = _readAttr(id);
        return (a.strength, a.element, a.gender, a.gen, a.genes, a.birthTime, a.cooldownEnd, a.motherId, a.fatherId);
    }

    function _readAttr(uint256 id) internal view returns (ApostleNFT.ApostleAttr memory) {
        (uint8 s, uint8 e, uint8 g, uint16 gen, uint256 genes, uint64 bt, uint64 cd, uint32 mid, uint32 fid)
            = apostle.attrs(id);
        return ApostleNFT.ApostleAttr(s, e, g, gen, genes, bt, cd, mid, fid);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return 0x150b7a02;
    }
}

// ── Dutch Auction ─────────────────────────────────────────────

contract LandAuction is Ownable {
    uint256 public constant FEE_BPS = 400;
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

// ── LandInitializer ───────────────────────────────────────────

contract LandInitializer is Ownable {
    LandNFT     public land;
    LandAuction public auction;
    address     public ring;

    constructor(address _land, address _auction, address _ring) {
        land=LandNFT(_land); auction=LandAuction(_auction); ring=_ring;
    }

    function batchMint(
        int16[] calldata xs,
        int16[] calldata ys,
        uint80[] calldata attrs_,
        address to
    ) external onlyOwner {
        for (uint256 i=0; i<xs.length; i++) {
            land.mint(to, xs[i], ys[i], attrs_[i]);
        }
    }

    function createGenesisAuctions(
        uint256[] calldata ids,
        uint128 startPrice,
        uint128 endPrice,
        uint64  duration
    ) external onlyOwner {
        for (uint256 i=0; i<ids.length; i++) {
            try auction.createAuction(ids[i], startPrice, endPrice, duration) {}
            catch {}
        }
    }
}
