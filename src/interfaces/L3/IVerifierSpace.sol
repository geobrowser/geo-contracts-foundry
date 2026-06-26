// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {ISpace} from 'interfaces/L3/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/L3/ISpaceRegistry.sol';

/**
 * @title IVerifierSpace
 * @notice Manages writing verification for a verifier space
 */
interface IVerifierSpace is ISpace {
  /**
   * @notice Message struct used to create offchain signatures for onchain verification
   * @dev Uses EIP 712 for hashing and signing of typed structured data
   * @param toSpaceId The space ID that will be written to
   * @param action The action identifier
   * @param subject The subject identifier
   * @param nonce The incremental counter to prevent signature reuse
   * @param data The data used for further execution
   */
  struct Message {
    bytes16 toSpaceId;
    bytes32 action;
    bytes32 subject;
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
   * @notice Initializes the contract
   * @param _initializerData The encoded initializer data:
   *        _spaceRegistry The address of the space registry contract
   *        _owner The address of the owner
   * @dev Skips `__EIP712_init`: the EIP712 domain already comes from `name()` / `version()` overrides, so extra
   *      storage would only add gas without changing signatures.
   */
  function initialize(bytes calldata _initializerData) external;

  /**
   * @notice Sets the writer validity status of a space ID
   * @dev Must be called by the owner
   * @param _spaceId The space ID of the writer
   * @param _valid Whether the writer will be valid
   */
  function setValidWriters(bytes16 _spaceId, bool _valid) external;

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
   * @notice EIP-712 v4 domain separator used by `verify` with `_hashTypedDataV4`
   * @dev OpenZeppelin EIP712 uses `name()` and `version()` (semver), so the signing domain tracks the live
   *      implementation after beacon upgrades. `initialize` skips `__EIP712_init` because nothing extra needs storing.
   * @return _domainSeparator The domain separator for this proxy
   */
  function domainSeparatorV4() external view returns (bytes32 _domainSeparator);
}
