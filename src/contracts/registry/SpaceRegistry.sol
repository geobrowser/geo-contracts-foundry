// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {ActionConstants} from 'contracts/ActionConstants.sol';
import {ISemver} from 'interfaces/ISemver.sol';
import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/registry/ISpaceRegistry.sol';

/**
 * @title SpaceRegistry
 * @notice Central registry for managing spaces
 * @dev This contract serves as the entry point for creating new spaces.
 *      Each space has a unique ID that maps to an address.
 *      Spaces can migrate to new addresses while keeping their ID.
 */
contract SpaceRegistry is OwnableUpgradeable, UUPSUpgradeable, ActionConstants, ISpaceRegistry {
  /// @inheritdoc ISpaceRegistry
  mapping(bytes16 => address) public spaceIdToAddress;

  /// @inheritdoc ISpaceRegistry
  mapping(bytes16 => address) public spaceIdToProposedAddress;

  /// @inheritdoc ISpaceRegistry
  mapping(address => bytes16) public addressToSpaceId;

  /// @notice The nonce used to generate a space ID for registration
  uint256 internal _spaceIdNonce;

  /// @notice Constructor
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc ISpaceRegistry
  function initialize(address _owner) external initializer {
    if (_owner == address(0)) revert InvalidZeroAddress();

    _transferOwnership(_owner);
  }

  /// @inheritdoc ISpaceRegistry
  function enter(
    address _from,
    address _to,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external {
    // Translate addresses into space IDs
    bytes16 fromId = addressToSpaceId[_from];
    bytes16 toId = addressToSpaceId[_to];

    // Check that the space IDs exist
    if (fromId == bytes16(0) || toId == bytes16(0)) revert SpaceNotRegistered();

    emit Action(fromId, toId, _action, _topic, _data);

    // If msg.sender is not the from
    // Then pass the to, action, topic, data, and signature for verification
    if (msg.sender != _from) ISpace(_from).verify(_to, _action, _topic, _data, _signature);

    // If msg.sender is not the to
    // Then pass the from, action, topic, and data to the space
    if (msg.sender != _to) ISpace(_to).write(_from, _action, _topic, _data);
  }

  /// @inheritdoc ISpaceRegistry
  function registerSpaceId() external {
    // Account must not be registered
    if (addressToSpaceId[msg.sender] != bytes16(0)) revert SpaceAlreadyRegistered();

    bytes16 spaceId = generateSpaceId(msg.sender, _spaceIdNonce++);

    addressToSpaceId[msg.sender] = spaceId;
    spaceIdToAddress[spaceId] = msg.sender;

    emit Action(bytes16(0), spaceId, SPACE_ID_REGISTERED, bytes32(bytes20(msg.sender)), '');
  }

  /// @inheritdoc ISpaceRegistry
  function proposeSpaceMigration(address _newAccount) external {
    // Must be called by the space itself
    bytes16 spaceId = addressToSpaceId[msg.sender];
    if (spaceId == bytes16(0)) revert InvalidCaller();

    spaceIdToProposedAddress[spaceId] = _newAccount;
  }

  /// @inheritdoc ISpaceRegistry
  function acceptSpaceMigration(bytes16 _spaceId) external {
    // Must be called by the proposed space itself
    if (spaceIdToProposedAddress[_spaceId] != msg.sender) revert InvalidCaller();

    // New address must not be registered
    if (addressToSpaceId[msg.sender] != bytes16(0)) revert SpaceAlreadyRegistered();

    address oldAccount = spaceIdToAddress[_spaceId];

    // Update the bi-directional mappings and reset the proposal
    spaceIdToProposedAddress[_spaceId] = address(0);
    spaceIdToAddress[_spaceId] = msg.sender;
    addressToSpaceId[oldAccount] = bytes16(0);
    addressToSpaceId[msg.sender] = _spaceId;

    emit Action(_spaceId, _spaceId, SPACE_ID_MIGRATED, bytes32(bytes20(msg.sender)), '');
  }

  /// @inheritdoc ISpaceRegistry
  function generateSpaceId(address _account, uint256 _nonce) public view returns (bytes16 spaceId) {
    spaceId = bytes16(keccak256(abi.encodePacked('grc20.space', _account, _nonce, block.chainid)));
  }

  /// @inheritdoc ISemver
  function version() public pure returns (string memory _version) {
    _version = '1.0.0';
  }

  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
