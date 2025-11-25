// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {BeaconProxy} from '@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol';
import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';

import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {ISemver} from 'interfaces/ISemver.sol';
import {IVerifierSpaceFactory} from 'interfaces/IVerifierSpaceFactory.sol';

/**
 * @title VerifierSpaceFactory
 * @notice Produces beacon-proxy-upgradeable verifier spaces
 */
contract VerifierSpaceFactory is UUPSUpgradeable, OwnableUpgradeable, IVerifierSpaceFactory {
  /// @inheritdoc IVerifierSpaceFactory
  address public verifierSpaceBeacon;

  /// @inheritdoc IVerifierSpaceFactory
  address public spaceRegistry;

  /// @notice Constructor
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IVerifierSpaceFactory
  function initialize(address _spaceRegistry, address _owner) external initializer {
    __Ownable_init(_owner);

    address verifierSpaceImplementation = address(new VerifierSpace());
    verifierSpaceBeacon = address(new UpgradeableBeacon(verifierSpaceImplementation, _owner));

    spaceRegistry = _spaceRegistry;
  }

  /// @inheritdoc IVerifierSpaceFactory
  function createVerifierSpaceProxy(address _owner) external returns (address _newVerifierSpaceProxy) {
    _newVerifierSpaceProxy =
      address(new BeaconProxy(verifierSpaceBeacon, abi.encodeCall(VerifierSpace.initialize, (spaceRegistry, _owner))));
    emit VerifierSpaceProxyCreated(_newVerifierSpaceProxy);
  }

  /// @inheritdoc ISemver
  function version() public pure returns (string memory _version) {
    _version = '1.0.0';
  }

  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
