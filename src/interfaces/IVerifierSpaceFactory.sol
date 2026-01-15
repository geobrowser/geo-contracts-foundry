// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title IVerifierSpaceFactory
 * @notice Produces beacon-proxy-upgradeable verifier spaces
 */
interface IVerifierSpaceFactory is ISemver {
  /**
   * @notice The storage struct of the verifier space factory contract
   * @param verifierSpaceBeacon The address of the verifier space beacon contract
   * @param spaceRegistry The address of the space registry contract
   * @param proxyIsChildOfFactory A mapping that tracks whether a proxy was produced by this factory
   * @custom:storage-location erc7201:geo.storage.VerifierSpaceFactory
   */
  struct VerifierSpaceFactoryStorage {
    address verifierSpaceBeacon;
    ISpaceRegistry spaceRegistry;
    mapping(address _proxy => bool _isChild) proxyIsChildOfFactory;
  }

  /**
   * @notice Initializes the contract
   * @param _initializerData The encoded initializer data:
   *        _spaceRegistry The address of the space registry contract
   *        _owner The address of the owner
   *        _verifierSpaceImplementation The address of a pre-deployed VerifierSpace implementation
   */
  function initialize(bytes calldata _initializerData) external;

  /**
   * @notice Creates a verifier space proxy contract
   * @dev Verifier space should register with space registry when initialized
   * @param _owner The address of the owner
   * @return _newVerifierSpaceProxy The address of the new verifier space proxy contract
   */
  function createVerifierSpaceProxy(address _owner) external returns (address _newVerifierSpaceProxy);

  /**
   * @notice Returns the verifier space beacon contract address
   * @return _verifierSpaceBeacon The address of the verifier space beacon contract
   */
  function verifierSpaceBeacon() external view returns (address _verifierSpaceBeacon);

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
