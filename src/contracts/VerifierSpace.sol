// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {EIP712Upgradeable} from '@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol';
import {SignatureChecker} from '@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol';

import {ISemver} from 'interfaces/ISemver.sol';
import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {IVerifierSpace} from 'interfaces/IVerifierSpace.sol';

/**
 * @title VerifierSpace
 * @notice Manages writing verification for a verifier space
 * @dev This contract validates off-chain messages passed to the SpaceRegistry when from ≠ msg.sender
 *      An arbitrary number of these contracts allows for an EOA (or a DAO) to control multiple spaces simultaneously
 */
contract VerifierSpace is OwnableUpgradeable, EIP712Upgradeable, IVerifierSpace {
  /// @inheritdoc IVerifierSpace
  bytes32 public constant MESSAGE_TYPEHASH =
    keccak256('Message(address toSpace,bytes32 action,bytes32 topic,uint256 nonce,bytes data)');

  /// @inheritdoc IVerifierSpace
  ISpaceRegistry public spaceRegistry;

  /// @inheritdoc IVerifierSpace
  mapping(address _account => bool _valid) public validWriters;

  /// @inheritdoc IVerifierSpace
  uint256 public replayNonce;

  /// @notice Constructor
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IVerifierSpace
  function initialize(bytes calldata _initializerData) external virtual initializer {
    // Decode initializer data
    (ISpaceRegistry _spaceRegistry, address _owner) = abi.decode(_initializerData, (ISpaceRegistry, address));
    // Initialise
    __Ownable_init(_owner);
    __EIP712_init('VERIFIER_SPACE', version());
    // Set Space Registry and register new DAO Space
    spaceRegistry = _spaceRegistry;
    _spaceRegistry.registerSpaceId();
    // Set valid writers
    _setValidWriters(_owner, true);
    _setValidWriters(address(this), true);
  }

  /// @inheritdoc IVerifierSpace
  function setValidWriters(address _account, bool _valid) external virtual onlyOwner {
    _setValidWriters(_account, _valid);
  }

  /// @inheritdoc ISpace
  function verify(
    address _toSpace,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external virtual {
    // Only space registry can call
    if (msg.sender != address(spaceRegistry)) revert InvalidCaller();
    // Construct the message hash and increment nonce to prevent replay
    bytes32 digest = _hashTypedDataV4(
      keccak256(abi.encode(MESSAGE_TYPEHASH, _toSpace, _action, _topic, replayNonce++, keccak256(_data)))
    );
    // Validate that owner is the signer of the message hash, revert if not
    if (!SignatureChecker.isValidSignatureNow(owner(), digest, _signature)) revert InvalidSignature();
  }

  /// @inheritdoc ISpace
  function write(address _fromSpace, bytes32, bytes32, bytes calldata) external view virtual {
    // Only space registry can call
    if (msg.sender != address(spaceRegistry)) revert InvalidCaller();
    // From space must be valid writer
    if (!validWriters[_fromSpace]) revert InvalidWriter();
  }

  /// @inheritdoc ISpace
  function fetch(bytes32, bytes32 _topicInput) public pure virtual returns (bytes32 _topicOutput) {
    _topicOutput = _topicInput;
  }

  /// @inheritdoc ISemver
  function version() public pure virtual returns (string memory _version) {
    _version = '1.0.0';
  }

  /**
   * @notice Sets the writer validity status of an address
   * @param _account The address of the writer
   * @param _valid Whether the writer will be valid
   */
  function _setValidWriters(address _account, bool _valid) internal virtual {
    validWriters[_account] = _valid;
    emit ValidWriterSet(_account, _valid);
  }
}
