// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ResourceToken
 * @dev Generic resource token used for GOLD, WOOD, HHO(Water), FIRE, SIOO(Soil).
 *      LandResource contract is the operator that mints mining rewards.
 */
contract ResourceToken is ERC20, Ownable {

    mapping(address => bool) public operators;

    modifier onlyOperator() {
        require(operators[msg.sender] || msg.sender == owner(), "Not operator");
        _;
    }

    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
        Ownable(msg.sender)
    {}

    function setOperator(address _operator, bool _enabled) external onlyOwner {
        operators[_operator] = _enabled;
    }

    function mint(address _to, uint256 _amount) external onlyOperator {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyOperator {
        _burn(_from, _amount);
    }
}
