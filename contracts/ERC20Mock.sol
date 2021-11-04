//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract ERC20Mock is ERC20 {
  constructor() ERC20('MockToken', 'MOCK') {
    _mint(msg.sender, 1000);
  }

  function mint(address receiver, uint256 amount) external {
    _mint(receiver, amount);
  }
}
