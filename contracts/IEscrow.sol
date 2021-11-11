//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEscrow {
    event TaskCreated(uint256 indexed taskId, address indexed sponsor, address indexed promoter);
}
