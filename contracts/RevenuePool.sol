// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title RevenuePool
 * @dev Collects auction fees. Owner can withdraw or distribute to stakers.
 */
contract RevenuePool is Ownable {

    IERC20 public ring;

    event Received(address indexed from, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);

    constructor(address _ring) Ownable(msg.sender) {
        ring = IERC20(_ring);
    }

    function balance() external view returns (uint256) {
        return ring.balanceOf(address(this));
    }

    function withdraw(address to, uint256 amount) external onlyOwner {
        require(ring.transfer(to, amount), "Transfer failed");
        emit Withdrawn(to, amount);
    }
}
