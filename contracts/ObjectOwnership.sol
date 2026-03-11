// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ObjectOwnership
 * @dev ERC721 for all game NFTs (lands, apostles). OZ v5 compatible.
 *      Operator contracts (LandBase, ClockAuction) can mint/transfer without per-token approval.
 */
contract ObjectOwnership is ERC721, Ownable {

    mapping(address => bool) public operators;

    event OperatorSet(address indexed operator, bool enabled);

    modifier onlyOperator() {
        require(operators[msg.sender] || msg.sender == owner(), "Not operator");
        _;
    }

    constructor() ERC721("Evolution Land Object", "ELO") Ownable(msg.sender) {}

    function setOperator(address _operator, bool _enabled) external onlyOwner {
        operators[_operator] = _enabled;
        emit OperatorSet(_operator, _enabled);
    }

    function mint(address _to, uint256 _tokenId) external onlyOperator {
        _safeMint(_to, _tokenId);
    }

    function burn(uint256 _tokenId) external onlyOperator {
        _burn(_tokenId);
    }

    /**
     * @dev Operator contracts can transfer any token without per-token approval.
     */
    function transferFrom(address from, address to, uint256 tokenId) public override {
        if (operators[msg.sender]) {
            _transfer(from, to, tokenId);
        } else {
            super.transferFrom(from, to, tokenId);
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override {
        if (operators[msg.sender]) {
            _transfer(from, to, tokenId);
            if (to.code.length > 0) {
                bytes4 retval = IERC721Receiver(to).onERC721Received(
                    msg.sender, from, tokenId, data
                );
                require(retval == IERC721Receiver.onERC721Received.selector,
                    "ERC721: non ERC721Receiver");
            }
        } else {
            super.safeTransferFrom(from, to, tokenId, data);
        }
    }
}
