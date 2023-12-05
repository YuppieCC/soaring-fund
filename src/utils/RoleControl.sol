// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";

abstract contract RoleControl is AccessControlUpgradeable {
    // administrator
    bytes32 public constant ADMIN = bytes32(keccak256(abi.encodePacked("ADMIN")));
}
