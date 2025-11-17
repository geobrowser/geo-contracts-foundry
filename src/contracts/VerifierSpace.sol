// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
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
contract VerifierSpace is UUPSUpgradeable, OwnableUpgradeable, IVerifierSpace {
  /// @inheritdoc IVerifierSpace
  ISpaceRegistry public spaceRegistry;

  /// @inheritdoc IVerifierSpace
  mapping(address _account => bool _valid) public validCallers;

  /// @inheritdoc IVerifierSpace
  uint256 public replayNonce;

  /// @notice Constructor
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IVerifierSpace
  function initialize(ISpaceRegistry _spaceRegistry, address _owner) external initializer {
    __Ownable_init(_owner);

    spaceRegistry = _spaceRegistry;
    validCallers[_owner] = true;
    validCallers[address(this)] = true;
  }

  /// @inheritdoc IVerifierSpace
  function setValidCallers(address _caller, bool _valid) external onlyOwner {
    validCallers[_caller] = _valid;
  }

  /// @inheritdoc ISpace
  function verify(
    address _toSpace,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external {
    // Construct the message hash and increment nonce to prevent replay
    bytes32 messageHash = keccak256(abi.encodePacked(_toSpace, _action, _topic, _data, replayNonce++, address(this)));

    // Validate that owner is the signer of the message hash, revert if not
    if (!SignatureChecker.isValidSignatureNow(owner(), messageHash, _signature)) revert InvalidSignature();
  }

  /// @inheritdoc ISpace
  function write(address _fromSpace, bytes32, bytes32, bytes calldata) external view {
    // Only space registry can call
    if (msg.sender != address(spaceRegistry)) revert InvalidCaller();
    // From space must be valid caller
    if (!validCallers[_fromSpace]) revert InvalidCaller();
  }

  /// @inheritdoc ISpace
  function fetch(bytes32, bytes32 _topicInput) public pure returns (bytes32 _topicOutput) {
    _topicOutput = _topicInput;
  }

  /// @inheritdoc ISemver
  function version() public pure returns (string memory _version) {
    _version = '1.0.0';
  }

  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
