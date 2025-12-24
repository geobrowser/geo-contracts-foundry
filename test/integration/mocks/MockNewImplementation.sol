// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {ISemver} from 'interfaces/ISemver.sol';

/**
 * @title MockNewImplementation
 * @notice Mock contract for testing new implementations
 */
contract MockNewImplementation is UUPSUpgradeable, ISemver {
  /// @inheritdoc ISemver
  function typeId() public pure returns (bytes32 _type) {
    _type = keccak256(bytes('MOCK'));
  }

  /// @inheritdoc ISemver
  function name() public pure returns (string memory _name) {
    _name = 'MOCK';
  }

  /// @inheritdoc ISemver
  function version() public pure returns (string memory _version) {
    _version = '2.0.0';
  }

  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address newImplementation) internal override {}
}
