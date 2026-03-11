// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RingToken (RING)
 * @dev Main game currency. Initial supply 10000 RING minted to deployer.
 *      Authorized operators (bank, auction) can mint rewards.
 */
contract RingToken is ERC20, Ownable {

    mapping(address => bool) public operators;

    event OperatorSet(address indexed operator, bool enabled);

    modifier onlyOperator() {
        require(operators[msg.sender] || msg.sender == owner(), "Not operator");
        _;
    }

    constructor() ERC20("Evolution Land Ring", "RING") Ownable(msg.sender) {
        // Mint 10000 RING to deployer for initial land auctions
        _mint(msg.sender, 10000 * 10**18);
    }

    function setOperator(address _operator, bool _enabled) external onlyOwner {
        operators[_operator] = _enabled;
        emit OperatorSet(_operator, _enabled);
    }

    function mint(address _to, uint256 _amount) external onlyOperator {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyOperator {
        _burn(_from, _amount);
    }
}
