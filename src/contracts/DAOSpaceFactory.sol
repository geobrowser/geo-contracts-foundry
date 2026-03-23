// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {BeaconProxy} from '@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol';
import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';

import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {IDAOSpaceFactory} from 'interfaces/IDAOSpaceFactory.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title DAOSpaceFactory
 * @notice Produces beacon-proxy-upgradeable DAO spaces
 * @custom:security WARNING: This contract has not been audited, may contain bugs, and should not be used to hold funds.
 */
contract DAOSpaceFactory is UUPSUpgradeable, OwnableUpgradeable, IDAOSpaceFactory {
  /**
   * @notice The storage location of the DAO space factory contract
   * @custom:storage-location erc7201:geo.storage.DAOSpaceFactory
   * @dev Computed with: keccak256(abi.encode(uint256(keccak256("geo.storage.DAOSpaceFactory")) - 1)) & ~bytes32(uint256(0xff))
   */
  bytes32 internal constant _DAO_SPACE_FACTORY_STORAGE_LOCATION =
    0x79f182c2bed0e30afe0ad6b057fc5f574a8b461be8bd0d1c0aab98f3c2fef400;

  /**
   * @notice Constructor
   * @custom:oz-upgrades-unsafe-allow constructor
   */
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IDAOSpaceFactory
  function initialize(bytes calldata _initializerData) external virtual initializer {
    // Decode initializer data
    (ISpaceRegistry _spaceRegistry, address _owner, address _daoSpaceImplementation) =
      abi.decode(_initializerData, (ISpaceRegistry, address, address));

    __Ownable_init(_owner);

    DAOSpaceFactoryStorage storage $_ = _getDAOSpaceFactoryStorage();
    $_.daoSpaceBeacon = address(new UpgradeableBeacon(_daoSpaceImplementation, _owner));
    $_.spaceRegistry = _spaceRegistry;
  }

  /// @inheritdoc IDAOSpaceFactory
  function createDAOSpaceProxy(
    IDAOSpace.VotingSettings calldata _votingSettings,
    bytes16[] calldata _initialEditors,
    bytes16[] calldata _initialMembers,
    bytes calldata _initialEditsContentUri,
    bytes calldata _initialEditsMetadata,
    bytes16 _initialTopicId
  ) external virtual returns (address _newDAOSpaceProxy) {
    DAOSpaceFactoryStorage storage $_ = _getDAOSpaceFactoryStorage();
    bytes memory _publishEditsData = (_initialEditsContentUri.length != 0 || _initialEditsMetadata.length != 0)
      ? abi.encode(_initialEditsContentUri, _initialEditsMetadata)
      : bytes('');
    bytes memory _initializerData = abi.encode(
      $_.spaceRegistry,
      _votingSettings,
      _initialEditors,
      _initialMembers,
      _publishEditsData,
      _initialTopicId,
      bytes16(0)
    );
    _newDAOSpaceProxy =
      address(new BeaconProxy($_.daoSpaceBeacon, abi.encodeCall(IDAOSpace.initialize, (_initializerData))));
    $_.proxyIsChildOfFactory[_newDAOSpaceProxy] = true;
  }

  /// @inheritdoc IDAOSpaceFactory
  function createDAOSpaceProxyForTransplant(
    IDAOSpace.VotingSettings calldata _votingSettings,
    bytes16[] calldata _initialEditors,
    bytes16[] calldata _initialMembers,
    bytes16 _transplantDAOSpaceId
  ) external virtual onlyOwner returns (address _newDAOSpaceProxy) {
    if (_transplantDAOSpaceId == bytes16(0)) revert InvalidTransplantDAOSpaceId();

    DAOSpaceFactoryStorage storage $_ = _getDAOSpaceFactoryStorage();
    bytes memory _initializerData = abi.encode(
      $_.spaceRegistry, _votingSettings, _initialEditors, _initialMembers, bytes(''), bytes16(0), _transplantDAOSpaceId
    );
    _newDAOSpaceProxy =
      address(new BeaconProxy($_.daoSpaceBeacon, abi.encodeCall(IDAOSpace.initialize, (_initializerData))));
    $_.proxyIsChildOfFactory[_newDAOSpaceProxy] = true;
  }

  /// @inheritdoc IDAOSpaceFactory
  function daoSpaceBeacon() public view returns (address _daoSpaceBeacon) {
    DAOSpaceFactoryStorage storage $_ = _getDAOSpaceFactoryStorage();
    _daoSpaceBeacon = $_.daoSpaceBeacon;
  }

  /// @inheritdoc IDAOSpaceFactory
  function spaceRegistry() public view returns (ISpaceRegistry _spaceRegistry) {
    DAOSpaceFactoryStorage storage $_ = _getDAOSpaceFactoryStorage();
    _spaceRegistry = $_.spaceRegistry;
  }

  /// @inheritdoc IDAOSpaceFactory
  function proxyIsChildOfFactory(address _proxy) public view returns (bool _isChild) {
    DAOSpaceFactoryStorage storage $_ = _getDAOSpaceFactoryStorage();
    _isChild = $_.proxyIsChildOfFactory[_proxy];
  }

  /// @inheritdoc ISemver
  function typeId() public pure virtual returns (bytes32 _type) {
    _type = keccak256(bytes(name()));
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
  function _authorizeUpgrade(address _newImplementation) internal virtual override onlyOwner {}

  /**
   * @notice Returns the DAO space factory contract storage
   * @return $_ The storage of the DAO space factory contract
   * @custom:storage-location erc7201:geo.storage.DAOSpaceFactory
   */
  function _getDAOSpaceFactoryStorage() internal pure returns (DAOSpaceFactoryStorage storage $_) {
    assembly {
      $_.slot := _DAO_SPACE_FACTORY_STORAGE_LOCATION
    }
  }
}
