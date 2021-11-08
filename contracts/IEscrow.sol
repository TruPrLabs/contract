//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEscrow {
    event TaskCreated(uint256 indexed taskId, address indexed sponsor, address indexed promoter);

    enum Platform {
        TWITTER,
        REDDIT,
        INSTAGRAM,
        DISCORD
    }

    enum Status {
        CLOSED,
        OPEN,
        FULFILLED
    }

    enum Metric {
        LIKES,
        RETWEETS,
        COMMENTS
    }
}
