// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {ISemver} from 'interfaces/ISemver.sol';

/**
 * @title IVerifierSpaceFactory
 * @notice Produces beacon-proxy-upgradeable verifier spaces
 */
interface IVerifierSpaceFactory is ISemver {
  /**
   * @notice Emitted when a verifier space proxy is created
   * @param newVerifierSpaceProxy The address of the new verifier space proxy contract
   */
  event VerifierSpaceProxyCreated(address newVerifierSpaceProxy);

  /**
   * @notice Returns the verifier space beacon contract address
   * @return _verifierSpaceBeacon The address of the verifier space beacon contract
   */
  function verifierSpaceBeacon() external view returns (address _verifierSpaceBeacon);

  /**
   * @notice Returns the space registry contract address
   * @return _spaceRegistry The address of the space registry contract
   */
  function spaceRegistry() external view returns (address _spaceRegistry);

  /**
   * @notice Initializes the contract
   * @param _spaceRegistry The address of the space registry contract
   * @param _owner The address of the owner
   */
  function initialize(address _spaceRegistry, address _owner) external;

  /**
   * @notice Creates a verifier space proxy contract
   * @dev Verifier space should register with space registry when initialized
   * @param _owner The address of the owner
   * @return _newVerifierSpaceProxy The address of the new verifier space proxy contract
   */
  function createVerifierSpaceProxy(address _owner) external returns (address _newVerifierSpaceProxy);
}
