// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ObjectOwnership
 * @dev ERC721 for all game NFTs (lands, apostles). OZ v5 compatible.
 *      Operator contracts (LandBase, ClockAuction) can mint/transfer without approval.
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

    // Allow operator contracts to transfer without needing explicit approval
    function transferFrom(address from, address to, uint256 tokenId) public override {
        if (operators[msg.sender]) {
            _transfer(from, to, tokenId);
        } else {
            super.transferFrom(from, to, tokenId);
        }
    }

    // OZ v5: safeTransferFrom calls _checkOnERC721Received internally after _transfer
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override {
        if (operators[msg.sender]) {
            _transfer(from, to, tokenId);
            _checkOnERC721Received(msg.sender, from, to, tokenId, data);
        } else {
            super.safeTransferFrom(from, to, tokenId, data);
        }
    }

    function _checkOnERC721Received(
        address operator_,
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(operator_, from, tokenId, data)
                returns (bytes4 retval) {
                require(retval == IERC721Receiver.onERC721Received.selector,
                    "ERC721: transfer to non ERC721Receiver");
            } catch {
                revert("ERC721: transfer to non ERC721Receiver");
            }
        }
    }
}

interface IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4);
}
