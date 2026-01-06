// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';

/**
 * @title IVerifierSpace
 * @notice Manages writing verification for a verifier space
 */
interface IVerifierSpace is ISpace {
  /**
   * @notice Message struct used to create offchain signatures for onchain verification
   * @dev Uses EIP 712 for hashing and signing of typed structured data
   * @param toSpace The space that will be written to
   * @param action The action identifier
   * @param topic The topic identifier
   * @param nonce The incremental counter to prevent signature reuse
   * @param data The data used for further execution
   */
  struct Message {
    address toSpace;
    bytes32 action;
    bytes32 topic;
    uint256 nonce;
    bytes data;
  }

  /**
   * @notice The storage struct of the verifier space contract
   * @param spaceRegistry The address of the space registry contract
   * @param validWriters Maps each address to its writer validity status
   * @param replayNonce Prevents transaction replay
   * @custom:storage-location erc7201:geo.storage.VerifierSpace
   */
  struct VerifierSpaceStorage {
    ISpaceRegistry spaceRegistry;
    mapping(address _account => bool _valid) validWriters;
    uint256 replayNonce;
  }

  /**
   * @notice Emitted when a writer validity status is set
   * @param account The address of the writer
   * @param valid Whether the writer is valid or not
   */
  event ValidWriterSet(address account, bool valid);

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
  function spaceRegistry() external view returns (ISpaceRegistry _spaceRegistry);

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
   * @param _initializerData The encoded initializer data:
   *        _spaceRegistry The address of the space registry contract
   *        _owner The address of the owner
   */
  function initialize(bytes calldata _initializerData) external;

  /**
   * @notice Sets the writer validity status of an address
   * @dev Must be called by the owner
   * @param _account The address of the writer
   * @param _valid Whether the writer will be valid
   */
  function setValidWriters(address _account, bool _valid) external;
}
