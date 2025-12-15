// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {BeaconProxy} from '@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol';
import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';

import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {ISemver} from 'interfaces/ISemver.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {IVerifierSpaceFactory} from 'interfaces/IVerifierSpaceFactory.sol';

/**
 * @title VerifierSpaceFactory
 * @notice Produces beacon-proxy-upgradeable verifier spaces
 */
contract VerifierSpaceFactory is UUPSUpgradeable, OwnableUpgradeable, IVerifierSpaceFactory {
  /// @inheritdoc IVerifierSpaceFactory
  address public verifierSpaceBeacon;

  /// @inheritdoc IVerifierSpaceFactory
  ISpaceRegistry public spaceRegistry;

  /// @notice Constructor
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IVerifierSpaceFactory
  function initialize(bytes calldata _initializerData) external virtual initializer {
    (ISpaceRegistry _spaceRegistry, address _owner) = abi.decode(_initializerData, (ISpaceRegistry, address));

    __Ownable_init(_owner);

    address verifierSpaceImplementation = address(new VerifierSpace());
    verifierSpaceBeacon = address(new UpgradeableBeacon(verifierSpaceImplementation, _owner));

    spaceRegistry = _spaceRegistry;
  }

  /// @inheritdoc IVerifierSpaceFactory
  function createVerifierSpaceProxy(address _owner) external virtual returns (address _newVerifierSpaceProxy) {
    bytes memory _initializerData = abi.encode(spaceRegistry, _owner);

    _newVerifierSpaceProxy =
      address(new BeaconProxy(verifierSpaceBeacon, abi.encodeCall(VerifierSpace.initialize, (_initializerData))));

    emit VerifierSpaceProxyCreated(_newVerifierSpaceProxy);
  }

  /// @inheritdoc ISemver
  function version() public pure virtual returns (string memory _version) {
    _version = '1.0.0';
  }

  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}
}
