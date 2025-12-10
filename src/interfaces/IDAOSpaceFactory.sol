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
   * @notice Emitted when a DAO space proxy is created
   * @param newDAOSpaceProxy The address of the new DAO space proxy contract
   */
  event DAOSpaceProxyCreated(address newDAOSpaceProxy);

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
   * @param _spaceRegistry The address of the space registry contract
   * @param _owner The address of the owner
   */
  function initialize(ISpaceRegistry _spaceRegistry, address _owner) external;

  /**
   * @notice Creates a DAO space proxy contract
   * @dev DAO space should register with space registry when initialized
   * @param _votingSettings The voting settings to use for proposals
   * @param _initialEditors The initial list of editor addresses
   * @param _initialMembers The initial list of member addresses
   * @return _newDAOSpaceProxy The address of the new DAO space proxy contract
   */
  function createDAOSpaceProxy(
    IDAOSpace.VotingSettings calldata _votingSettings,
    address[] calldata _initialEditors,
    address[] calldata _initialMembers
  ) external returns (address _newDAOSpaceProxy);
}
