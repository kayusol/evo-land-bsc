// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title KtonToken (KTON)
 * @dev Diamond token, earned by staking RING in the bank.
 */
contract KtonToken is ERC20, Ownable {

    mapping(address => bool) public operators;

    modifier onlyOperator() {
        require(operators[msg.sender] || msg.sender == owner(), "Not operator");
        _;
    }

    constructor() ERC20("Evolution Land Kton", "KTON") Ownable(msg.sender) {}

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
