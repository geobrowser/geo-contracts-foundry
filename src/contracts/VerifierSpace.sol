// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {EIP712Upgradeable} from '@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol';
import {SignatureChecker} from '@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol';

import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {IVerifierSpace} from 'interfaces/IVerifierSpace.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title VerifierSpace
 * @notice Manages writing verification for a verifier space
 * @dev This contract validates off-chain messages passed to the SpaceRegistry when from ≠ msg.sender
 *      An arbitrary number of these contracts allows for an EOA (or a DAO) to control multiple spaces simultaneously
 * @custom:security WARNING: This contract has not been audited and should not be used to hold funds.
 */
contract VerifierSpace is OwnableUpgradeable, EIP712Upgradeable, IVerifierSpace {
  /// @inheritdoc IVerifierSpace
  bytes32 public constant MESSAGE_TYPEHASH =
    keccak256('Message(bytes16 toSpaceId,bytes32 action,bytes32 subject,uint256 nonce,bytes data)');

  /**
   * @notice The storage location of the verifier space contract
   * @custom:storage-location erc7201:geo.storage.VerifierSpace
   * @dev Computed with: keccak256(abi.encode(uint256(keccak256("geo.storage.VerifierSpace")) - 1)) & ~bytes32(uint256(0xff))
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
    __EIP712_init(name(), version());

    // Set Space Registry and register new Verifier Space
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();
    $.spaceRegistry = _spaceRegistry;
    bytes16 _verifierSpaceId = _spaceRegistry.registerSpaceId(typeId(), abi.encode(version()));

    // Set valid writers
    _setValidWriters(_spaceRegistry.addressToSpaceId(_owner), true);
    _setValidWriters(_verifierSpaceId, true);
  }

  /// @inheritdoc IVerifierSpace
  function setValidWriters(bytes16 _spaceId, bool _valid) external virtual onlyOwner {
    _setValidWriters(_spaceId, _valid);
  }

  /// @inheritdoc ISpace
  function verify(
    address,
    bytes16 _toSpaceId,
    bytes32 _action,
    bytes32 _subject,
    bytes calldata _data,
    bytes calldata _signature
  ) external virtual {
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();

    // Only space registry can call
    if (msg.sender != address($.spaceRegistry)) revert InvalidCaller();
    // Construct the message hash and increment nonce to prevent replay
    bytes32 digest = _hashTypedDataV4(
      keccak256(abi.encode(MESSAGE_TYPEHASH, _toSpaceId, _action, _subject, $.replayNonce++, keccak256(_data)))
    );
    // Validate that owner is the signer of the message hash, revert if not
    if (!SignatureChecker.isValidSignatureNow(owner(), digest, _signature)) revert InvalidSignature();
  }

  /// @inheritdoc ISpace
  function write(bytes16 _fromSpaceId, bytes32, bytes32, bytes calldata) external view virtual {
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();

    // Only space registry can call
    if (msg.sender != address($.spaceRegistry)) revert InvalidCaller();
    // From space must be valid writer
    if (!$.validWriters[_fromSpaceId]) revert InvalidWriter();
  }

  /// @inheritdoc IVerifierSpace
  function spaceRegistry() public view returns (ISpaceRegistry _spaceRegistry) {
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();
    _spaceRegistry = $.spaceRegistry;
  }

  /// @inheritdoc IVerifierSpace
  function validWriters(bytes16 _spaceId) public view returns (bool _valid) {
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();
    _valid = $.validWriters[_spaceId];
  }

  /// @inheritdoc IVerifierSpace
  function replayNonce() public view returns (uint256 _replayNonce) {
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();
    _replayNonce = $.replayNonce;
  }

  /// @inheritdoc ISpace
  function fetch(bytes32, bytes32 _subjectInput, bytes calldata) public pure virtual returns (bytes32 _subjectOutput) {
    _subjectOutput = _subjectInput;
  }

  /// @inheritdoc ISemver
  function typeId() public pure virtual returns (bytes32 _type) {
    _type = keccak256(bytes(name()));
  }

  /// @inheritdoc ISemver
  function name() public pure virtual returns (string memory _name) {
    _name = 'VERIFIER_SPACE';
  }

  /// @inheritdoc ISemver
  function version() public pure virtual returns (string memory _version) {
    _version = '1.0.0';
  }

  /**
   * @notice Sets the writer validity status of a space ID
   * @param _spaceId The space ID of the writer
   * @param _valid Whether the writer will be valid
   */
  function _setValidWriters(bytes16 _spaceId, bool _valid) internal virtual {
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();
    $.validWriters[_spaceId] = _valid;
    emit ValidWriterSet(_spaceId, _valid);
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
