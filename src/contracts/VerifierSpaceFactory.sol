// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {BeaconProxy} from '@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol';
import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';

import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {IVerifierSpace} from 'interfaces/IVerifierSpace.sol';
import {IVerifierSpaceFactory} from 'interfaces/IVerifierSpaceFactory.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title VerifierSpaceFactory
 * @notice Produces beacon-proxy-upgradeable verifier spaces
 */
contract VerifierSpaceFactory is UUPSUpgradeable, OwnableUpgradeable, IVerifierSpaceFactory {
  /**
   * @notice The storage location of the verifier space factory contract
   * @custom:storage-location erc7201:geo.storage.VerifierSpaceFactory
   */
  bytes32 internal constant _VERIFIER_SPACE_FACTORY_STORAGE_LOCATION =
    0x83d3ab5f19d81a7926e12e3baadc64405a79e75661a4c7f5ad3f370d8dc93500;

  /// @notice Constructor
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IVerifierSpaceFactory
  function initialize(bytes calldata _initializerData) external virtual initializer {
    (ISpaceRegistry _spaceRegistry, address _owner, address _verifierSpaceImplementation) =
      abi.decode(_initializerData, (ISpaceRegistry, address, address));

    __Ownable_init(_owner);

    VerifierSpaceFactoryStorage storage $ = _getVerifierSpaceFactoryStorage();
    $.verifierSpaceBeacon = address(new UpgradeableBeacon(_verifierSpaceImplementation, _owner));
    $.spaceRegistry = _spaceRegistry;
  }

  /// @inheritdoc IVerifierSpaceFactory
  function createVerifierSpaceProxy(address _owner) external virtual returns (address _newVerifierSpaceProxy) {
    VerifierSpaceFactoryStorage storage $ = _getVerifierSpaceFactoryStorage();

    bytes memory _initializerData = abi.encode($.spaceRegistry, _owner);
    _newVerifierSpaceProxy =
      address(new BeaconProxy($.verifierSpaceBeacon, abi.encodeCall(IVerifierSpace.initialize, (_initializerData))));
  }

  /// @inheritdoc IVerifierSpaceFactory
  function verifierSpaceBeacon() public view returns (address _verifierSpaceBeacon) {
    VerifierSpaceFactoryStorage storage $ = _getVerifierSpaceFactoryStorage();
    _verifierSpaceBeacon = $.verifierSpaceBeacon;
  }

  /// @inheritdoc IVerifierSpaceFactory
  function spaceRegistry() public view returns (ISpaceRegistry _spaceRegistry) {
    VerifierSpaceFactoryStorage storage $ = _getVerifierSpaceFactoryStorage();
    _spaceRegistry = $.spaceRegistry;
  }

  /// @inheritdoc ISemver
  function typeId() public pure virtual returns (bytes32 _type) {
    _type = keccak256('VERIFIER_SPACE_FACTORY');
  }

  /// @inheritdoc ISemver
  function name() public pure virtual returns (string memory _name) {
    _name = 'VERIFIER_SPACE_FACTORY';
  }

  /// @inheritdoc ISemver
  function version() public pure virtual returns (string memory _version) {
    _version = '1.0.0';
  }

  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

  /**
   * @notice Returns the verifier space factory contract storage
   * @return $ The storage of the verifier space factory contract
   * @custom:storage-location erc7201:geo.storage.VerifierSpaceFactory
   */
  function _getVerifierSpaceFactoryStorage() internal pure returns (VerifierSpaceFactoryStorage storage $) {
    assembly {
      $.slot := _VERIFIER_SPACE_FACTORY_STORAGE_LOCATION
    }
  }
}
