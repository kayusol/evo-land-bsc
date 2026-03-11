// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ObjectOwnership
 * @dev ERC721 base for land and apostle NFTs.
 *      Authorized operators (other game contracts) can mint/burn/transfer.
 *      Compatible with OpenZeppelin v5.
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
     * @dev Override transferFrom to allow authorized operators to transfer on behalf.
     *      OZ v5 compatible - checks approval internally via _isAuthorized.
     */
    function transferFrom(address from, address to, uint256 tokenId) public override {
        if (operators[msg.sender]) {
            _transfer(from, to, tokenId);
        } else {
            super.transferFrom(from, to, tokenId);
        }
    }

    /**
     * @dev Override safeTransferFrom (4-arg version). OZ v5 signature unchanged.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        if (operators[msg.sender]) {
            _safeTransfer(from, to, tokenId, data);
        } else {
            super.safeTransferFrom(from, to, tokenId, data);
        }
    }
}
