//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract Treasury {
    address private owner;

    constructor() {
        owner = msg.sender;
    }

    function withdrawToken(address token) external {
        require(msg.sender == owner, 'caller is not the owner');
        uint256 balance = IERC20(token).balanceOf(address(this));
        bool transferSuccessful = IERC20(token).transfer(owner, balance);
        require(transferSuccessful, 'ERC20 Token could not be transferred');
    }

    function withdraw() external {
        require(msg.sender == owner, 'caller is not the owner');
        (bool success, bytes memory returndata) = owner.call{value: address(this).balance}('');
        require(success, 'balance could not be transferred');
    }
}
