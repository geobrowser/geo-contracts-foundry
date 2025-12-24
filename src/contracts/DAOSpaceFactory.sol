// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {BeaconProxy} from '@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol';
import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';

import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {IDAOSpaceFactory} from 'interfaces/IDAOSpaceFactory.sol';
import {ISemver} from 'interfaces/ISemver.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';

/**
 * @title DAOSpaceFactory
 * @notice Produces beacon-proxy-upgradeable DAO spaces
 */
contract DAOSpaceFactory is UUPSUpgradeable, OwnableUpgradeable, IDAOSpaceFactory {
  /**
   * @notice The storage location of the DAO space factory contract
   * @custom:storage-location erc7201:geo.storage.DAOSpaceFactory
   */
  bytes32 internal constant _DAO_SPACE_FACTORY_STORAGE_LOCATION =
    0x79f182c2bed0e30afe0ad6b057fc5f574a8b461be8bd0d1c0aab98f3c2fef400;

  /// @notice Constructor
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IDAOSpaceFactory
  function initialize(bytes calldata _initializerData) external virtual initializer {
    (ISpaceRegistry _spaceRegistry, address _owner, address _daoSpaceImplementation) =
      abi.decode(_initializerData, (ISpaceRegistry, address, address));

    __Ownable_init(_owner);

    DAOSpaceFactoryStorage storage $ = _getDAOSpaceFactoryStorage();
    $.daoSpaceBeacon = address(new UpgradeableBeacon(_daoSpaceImplementation, _owner));
    $.spaceRegistry = _spaceRegistry;
  }

  /// @inheritdoc IDAOSpaceFactory
  function createDAOSpaceProxy(
    IDAOSpace.VotingSettings calldata _votingSettings,
    address[] calldata _initialEditors,
    address[] calldata _initialMembers,
    bytes calldata _initialEditsContentUri,
    bytes calldata _initialEditsMetadata
  ) external virtual returns (address _newDAOSpaceProxy) {
    DAOSpaceFactoryStorage storage $ = _getDAOSpaceFactoryStorage();

    bytes memory _initializerData = abi.encode(
      $.spaceRegistry,
      _votingSettings,
      _initialEditors,
      _initialMembers,
      abi.encode(_initialEditsContentUri, _initialEditsMetadata)
    );
    _newDAOSpaceProxy =
      address(new BeaconProxy($.daoSpaceBeacon, abi.encodeCall(IDAOSpace.initialize, (_initializerData))));
  }

  /// @inheritdoc IDAOSpaceFactory
  function daoSpaceBeacon() public view returns (address _daoSpaceBeacon) {
    DAOSpaceFactoryStorage storage $ = _getDAOSpaceFactoryStorage();
    _daoSpaceBeacon = $.daoSpaceBeacon;
  }

  /// @inheritdoc IDAOSpaceFactory
  function spaceRegistry() public view returns (ISpaceRegistry _spaceRegistry) {
    DAOSpaceFactoryStorage storage $ = _getDAOSpaceFactoryStorage();
    _spaceRegistry = $.spaceRegistry;
  }

  /// @inheritdoc ISemver
  function typeId() public pure virtual returns (bytes32 _type) {
    _type = keccak256(bytes('DAO_SPACE_FACTORY'));
  }

  /// @inheritdoc ISemver
  function name() public pure virtual returns (string memory _name) {
    _name = 'DAO_SPACE_FACTORY';
  }

  /// @inheritdoc ISemver
  function version() public pure virtual returns (string memory _version) {
    _version = '1.0.0';
  }

  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

  /**
   * @notice Returns the DAO space factory contract storage
   * @return $ The storage of the DAO space factory contract
   * @custom:storage-location erc7201:geo.storage.DAOSpaceFactory
   */
  function _getDAOSpaceFactoryStorage() internal pure returns (DAOSpaceFactoryStorage storage $) {
    assembly {
      $.slot := _DAO_SPACE_FACTORY_STORAGE_LOCATION
    }
  }
}
