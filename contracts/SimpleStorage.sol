// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleStorage {
    uint256 public storedValue;

    function set(uint256 _value) external {
        require(_value <= 1000, "Value too high");
        storedValue = _value;
    }

    function get() external view returns (uint256) {
        return storedValue;
    }
}
