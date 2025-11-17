// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {ISemver} from 'interfaces/ISemver.sol';
import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';

/**
 * @title IVerifierSpace
 * @notice Manages writing verification for a verifier space
 */
interface IVerifierSpace is ISpace, ISemver {
  /// @notice Thrown when the caller is not authorized for the operation
  error InvalidCaller();

  /// @notice Thrown when the owner is not the signer of the message hash
  error InvalidSignature();

  /**
   * @notice Returns the space registry contract
   * @return _spaceRegistry The address of the space registry contract
   */
  function spaceRegistry() external view returns (ISpaceRegistry _spaceRegistry);

  /**
   * @notice Maps each address to its call validity status
   * @param _account The address of the caller
   * @return _valid Whether the caller is valid or not
   */
  function validCallers(address _account) external view returns (bool _valid);

  /**
   * @notice Prevents transaction replay
   * @return _replayNonce The nonce used to prevent replay
   */
  function replayNonce() external view returns (uint256 _replayNonce);

  /**
   * @notice Initializes the contract
   * @param _spaceRegistry The address of the space registry contract
   * @param _owner The address of the owner
   */
  function initialize(ISpaceRegistry _spaceRegistry, address _owner) external;

  /**
   * @notice Sets the call validity status of an address
   * @param _account The address of the caller
   * @param _valid Whether the caller will be valid
   */
  function setValidCallers(address _account, bool _valid) external;
}
