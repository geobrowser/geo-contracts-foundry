// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {ISemver} from 'interfaces/ISemver.sol';
import {ISpace} from 'interfaces/ISpace.sol';

/**
 * @title IVerifierSpace
 * @notice Manages writing verification for a verifier space
 */
interface IVerifierSpace is ISpace, ISemver {
  /// @notice Thrown when the caller is not authorized for the operation
  error InvalidCaller();

  /// @notice Thrown when the writer is not authorized for the operation
  error InvalidWriter();

  /// @notice Thrown when the owner is not the signer of the message hash
  error InvalidSignature();

  /**
   * @notice Returns the space registry contract address
   * @return _spaceRegistry The address of the space registry contract
   */
  function spaceRegistry() external view returns (address _spaceRegistry);

  /**
   * @notice Maps each address to its writer validity status
   * @param _account The address of the writer
   * @return _valid Whether the writer is valid or not
   */
  function validWriters(address _account) external view returns (bool _valid);

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
  function initialize(address _spaceRegistry, address _owner) external;

  /**
   * @notice Sets the writer validity status of an address
   * @param _account The address of the writer
   * @param _valid Whether the writer will be valid
   */
  function setValidWriters(address _account, bool _valid) external;
}
