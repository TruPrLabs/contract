//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ScoreFn {
    struct Data {
        bool linear;
        uint64[] x;
        uint64[] y;
    }

    uint256 constant MAX_VALUE = type(uint64).max;

    function evaluate(
        Data memory self,
        uint64 x,
        uint256 multiplier
    ) external pure returns (uint256) {
        // requires: x[-1] == MAX_VALUE
        if (x == MAX_VALUE) {
            if (self.y[self.y.length - 1] == MAX_VALUE) return multiplier;
            return (((multiplier >> 64) * self.y[self.y.length - 1]) / MAX_VALUE) << 64; // guard against overflow
        }
        // follows: x < MAX_VALUE

        uint256 i;
        // requires: x[i] < x[i+1]
        // requires: x[-1] == MAX_VALUE
        while (x < self.x[i]) i++;
        // follows:  i <= x.length

        // requires: y.length == x.length
        uint64 y0 = (i == 0) ? 0 : self.y[i - 1]; // implicit 0 added

        if (!self.linear) return y0; // return left value for piecewise-continuous functions

        uint64 y1 = self.y[i];

        uint64 x0 = (i == 0) ? 0 : self.x[i - 1]; // implicit 0 added
        uint64 x1 = self.x[i];

        // calculate in lower precision to avoid overflow
        return (((multiplier >> 64) * (y0 + (uint256(y1) * (x - x0)) / (x1 - x0))) / MAX_VALUE) << 64;
    }
}
