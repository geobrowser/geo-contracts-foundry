// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {BeaconProxy} from '@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol';
import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {IDAOSpaceFactory} from 'interfaces/IDAOSpaceFactory.sol';
import {ISemver} from 'interfaces/ISemver.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';

/**
 * @title DAOSpaceFactory
 * @notice Produces beacon-proxy-upgradeable DAO spaces
 */
contract DAOSpaceFactory is UUPSUpgradeable, OwnableUpgradeable, IDAOSpaceFactory {
  /// @inheritdoc IDAOSpaceFactory
  address public daoSpaceBeacon;

  /// @inheritdoc IDAOSpaceFactory
  ISpaceRegistry public spaceRegistry;

  /// @notice Constructor
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IDAOSpaceFactory
  function initialize(ISpaceRegistry _spaceRegistry, address _owner) external virtual initializer {
    __Ownable_init(_owner);

    address daoSpaceImplementation = address(new DAOSpace());
    daoSpaceBeacon = address(new UpgradeableBeacon(daoSpaceImplementation, _owner));

    spaceRegistry = _spaceRegistry;
  }

  /// @inheritdoc IDAOSpaceFactory
  function createDAOSpaceProxy(
    DAOSpace.VotingSettings calldata _votingSettings,
    address[] calldata _initialEditors,
    address[] calldata _initialMembers
  ) external virtual returns (address _newDAOSpaceProxy) {
    _newDAOSpaceProxy = address(
      new BeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(DAOSpace.initialize, (spaceRegistry, _votingSettings, _initialEditors, _initialMembers))
      )
    );
    emit DAOSpaceProxyCreated(_newDAOSpaceProxy);
  }

  /// @inheritdoc ISemver
  function version() public pure virtual returns (string memory _version) {
    _version = '1.0.0';
  }

  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}
}
