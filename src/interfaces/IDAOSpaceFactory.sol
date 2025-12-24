// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {ISemver} from 'interfaces/ISemver.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';

/**
 * @title IDAOSpaceFactory
 * @notice Produces beacon-proxy-upgradeable DAO spaces
 */
interface IDAOSpaceFactory is ISemver {
  /**
   * @notice The storage struct of the DAO space factory contract
   * @param daoSpaceBeacon The address of the DAO space beacon contract
   * @param spaceRegistry The address of the space registry contract
   * @custom:storage-location erc7201:geo.storage.DAOSpaceFactory
   */
  struct DAOSpaceFactoryStorage {
    address daoSpaceBeacon;
    ISpaceRegistry spaceRegistry;
  }

  /**
   * @notice Returns the DAO space beacon contract address
   * @return _daoSpaceBeacon The address of the DAO space beacon contract
   */
  function daoSpaceBeacon() external view returns (address _daoSpaceBeacon);

  /**
   * @notice Returns the space registry contract address
   * @return _spaceRegistry The address of the space registry contract
   */
  function spaceRegistry() external view returns (ISpaceRegistry _spaceRegistry);

  /**
   * @notice Initializes the contract
   * @param _initializerData The encoded initializer data:
   *        _spaceRegistry The address of the space registry contract
   *        _owner The address of the owner
   *        _daoSpaceImplementation The address of a pre-deployed DAOSpace implementation
   */
  function initialize(bytes calldata _initializerData) external;

  /**
   * @notice Creates a DAO space proxy contract
   * @dev DAO space should register with space registry when initialized
   * @param _votingSettings The voting settings to use for proposals
   * @param _initialEditors The initial list of editor addresses
   * @param _initialMembers The initial list of member addresses
   * @param _initialEditsContentUri The initial edit publish content uri
   * @param _initialEditsMetadata The initial edit publish metadata
   * @return _newDAOSpaceProxy The address of the new DAO space proxy contract
   */
  function createDAOSpaceProxy(
    IDAOSpace.VotingSettings calldata _votingSettings,
    address[] calldata _initialEditors,
    address[] calldata _initialMembers,
    bytes calldata _initialEditsContentUri,
    bytes calldata _initialEditsMetadata
  ) external returns (address _newDAOSpaceProxy);
}
