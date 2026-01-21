// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title IDAOSpaceFactory
 * @notice Produces beacon-proxy-upgradeable DAO spaces
 */
interface IDAOSpaceFactory is ISemver {
  /**
   * @notice The storage struct of the DAO space factory contract
   * @param daoSpaceBeacon The address of the DAO space beacon contract
   * @param spaceRegistry The address of the space registry contract
   * @param proxyIsChildOfFactory A mapping that tracks whether a proxy was produced by this factory
   * @custom:storage-location erc7201:geo.storage.DAOSpaceFactory
   */
  struct DAOSpaceFactoryStorage {
    address daoSpaceBeacon;
    ISpaceRegistry spaceRegistry;
    mapping(address _proxy => bool _isChild) proxyIsChildOfFactory;
  }

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
   * @param _initialEditors The initial list of editor space IDs
   * @param _initialMembers The initial list of member space IDs
   * @param _initialEditsContentUri The initial edit publish content uri
   * @param _initialEditsMetadata The initial edit publish metadata
   * @param _initialTopicId The initial topic ID to declare
   * @return _newDAOSpaceProxy The address of the new DAO space proxy contract
   */
  function createDAOSpaceProxy(
    IDAOSpace.VotingSettings calldata _votingSettings,
    bytes16[] calldata _initialEditors,
    bytes16[] calldata _initialMembers,
    bytes calldata _initialEditsContentUri,
    bytes calldata _initialEditsMetadata,
    bytes16 _initialTopicId
  ) external returns (address _newDAOSpaceProxy);

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
   * @notice Checks whether a proxy address was created by this factory
   * @param _proxy The proxy address to check
   * @return _isChild True if the proxy was created by this factory, false otherwise
   */
  function proxyIsChildOfFactory(address _proxy) external view returns (bool _isChild);
}
