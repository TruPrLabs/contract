//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MOCKERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000);
    }

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }

    function mintFor(address receiver, uint256 amount) external {
        _mint(receiver, amount);
    }
}
