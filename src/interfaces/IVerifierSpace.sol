// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title IVerifierSpace
 * @notice Manages writing verification for a verifier space
 */
interface IVerifierSpace is ISpace, ISemver {
  /**
   * @notice Message struct used to create offchain signatures for onchain verification
   * @dev Uses EIP 712 for hashing and signing of typed structured data
   * @param toSpaceId The space ID that will be written to
   * @param action The action identifier
   * @param topic The topic identifier
   * @param nonce The incremental counter to prevent signature reuse
   * @param data The data used for further execution
   */
  struct Message {
    bytes16 toSpaceId;
    bytes32 action;
    bytes32 topic;
    uint256 nonce;
    bytes data;
  }

  /**
   * @notice The storage struct of the verifier space contract
   * @param spaceRegistry The address of the space registry contract
   * @param validWriters Maps each space ID to its writer validity status
   * @param replayNonce Prevents transaction replay
   * @custom:storage-location erc7201:geo.storage.VerifierSpace
   */
  struct VerifierSpaceStorage {
    ISpaceRegistry spaceRegistry;
    mapping(bytes16 _spaceId => bool _valid) validWriters;
    uint256 replayNonce;
  }

  /**
   * @notice Emitted when a writer validity status is set
   * @param spaceId The space ID of the writer
   * @param valid Whether the writer is valid or not
   */
  event ValidWriterSet(bytes16 spaceId, bool valid);

  /// @notice Thrown when the caller is not authorized for the operation
  error InvalidCaller();

  /// @notice Thrown when the writer is not authorized for the operation
  error InvalidWriter();

  /// @notice Thrown when the owner is not the signer of the message hash
  error InvalidSignature();

  /**
   * @notice The message typehash for the struct used in the signature verification
   * @return _messageTypehash The bytes32 message typehash constant
   */
  function MESSAGE_TYPEHASH() external view returns (bytes32 _messageTypehash);

  /**
   * @notice Returns the space registry contract address
   * @return _spaceRegistry The address of the space registry contract
   */
  function spaceRegistry() external view returns (ISpaceRegistry _spaceRegistry);

  /**
   * @notice Maps each space ID to its writer validity status
   * @param _spaceId The space ID of the writer
   * @return _valid Whether the writer is valid or not
   */
  function validWriters(bytes16 _spaceId) external view returns (bool _valid);

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
   * @notice Sets the writer validity status of a space ID
   * @dev Must be called by the owner
   * @param _spaceId The space ID of the writer
   * @param _valid Whether the writer will be valid
   */
  function setValidWriters(bytes16 _spaceId, bool _valid) external;
}
