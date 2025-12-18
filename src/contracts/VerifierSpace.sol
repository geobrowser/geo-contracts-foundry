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
  // REVIEW: Internalize?
  bytes32 public constant MESSAGE_TYPEHASH =
    keccak256('Message(address toSpace,bytes32 action,bytes32 topic,uint256 nonce,bytes data)');

  /**
   * @notice The storage location of the verifier space contract
   * @custom:storage-location erc7201:geo.storage.VerifierSpace
   */
  bytes32 internal constant _VERIFIER_SPACE_STORAGE_LOCATION =
    0xc1676672be845731e27a8a9dcb0bb8dcd73102852fa8f3d5fb86df9b24265c00;

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
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();
    $.spaceRegistry = _spaceRegistry;
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
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();

    // Only space registry can call
    if (msg.sender != address($.spaceRegistry)) revert InvalidCaller();
    // Construct the message hash and increment nonce to prevent replay
    bytes32 digest = _hashTypedDataV4(
      keccak256(abi.encode(MESSAGE_TYPEHASH, _toSpace, _action, _topic, $.replayNonce++, keccak256(_data)))
    );
    // Validate that owner is the signer of the message hash, revert if not
    if (!SignatureChecker.isValidSignatureNow(owner(), digest, _signature)) revert InvalidSignature();
  }

  /// @inheritdoc ISpace
  function write(address _fromSpace, bytes32, bytes32, bytes calldata) external view virtual {
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();

    // Only space registry can call
    if (msg.sender != address($.spaceRegistry)) revert InvalidCaller();
    // From space must be valid writer
    if (!$.validWriters[_fromSpace]) revert InvalidWriter();
  }

  /// @inheritdoc IVerifierSpace
  function spaceRegistry() public view returns (ISpaceRegistry _spaceRegistry) {
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();
    _spaceRegistry = $.spaceRegistry;
  }

  /// @inheritdoc IVerifierSpace
  function validWriters(address _account) public view returns (bool _valid) {
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();
    _valid = $.validWriters[_account];
  }

  /// @inheritdoc IVerifierSpace
  function replayNonce() public view returns (uint256 _replayNonce) {
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();
    _replayNonce = $.replayNonce;
  }

  /// @inheritdoc ISpace
  function fetch(bytes32, bytes32 _topicInput, bytes calldata) public pure virtual returns (bytes32 _topicOutput) {
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
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();
    $.validWriters[_account] = _valid;
    emit ValidWriterSet(_account, _valid);
  }

  /**
   * @notice Returns the verifier space contract storage
   * @return $ The storage of the verifier space contract
   * @custom:storage-location erc7201:geo.storage.VerifierSpace
   */
  function _getVerifierSpaceStorage() internal pure returns (VerifierSpaceStorage storage $) {
    assembly {
      $.slot := _VERIFIER_SPACE_STORAGE_LOCATION
    }
  }
}
