// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {ISemver} from 'interfaces/ISemver.sol';
import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';

import 'src/ActionsConstants.sol' as ActionsConstants;

/**
 * @title SpaceRegistry
 * @notice Central registry for managing spaces
 * @dev This contract serves as the entry point for creating new spaces
 *      Each space has a unique ID that maps to an address
 *      Spaces can migrate to new addresses while keeping their ID
 */
contract SpaceRegistry is UUPSUpgradeable, OwnableUpgradeable, ISpaceRegistry {
  /// @inheritdoc ISpaceRegistry
  mapping(bytes16 _spaceId => address _account) public spaceIdToAddress;

  /// @inheritdoc ISpaceRegistry
  mapping(bytes16 _spaceId => address _account) public spaceIdToProposedAddress;

  /// @inheritdoc ISpaceRegistry
  mapping(address _account => bytes16 _spaceId) public addressToSpaceId;

  /// @inheritdoc ISpaceRegistry
  mapping(bytes32 _action => bool _isPermissionless) public permissionlessActions;

  /// @notice The nonce used to generate a space ID for registration
  uint256 internal _spaceIdNonce;

  /// @notice Constructor
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc ISpaceRegistry
  function initialize(bytes calldata _initializerData) external virtual initializer {
    address _owner = abi.decode(_initializerData, (address));

    __Ownable_init(_owner);
  }

  /// @inheritdoc ISpaceRegistry
  function enter(
    address _from,
    address _to,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external virtual {
    // Translate addresses into space IDs
    bytes16 fromId = addressToSpaceId[_from];
    bytes16 toId = addressToSpaceId[_to];

    // Check that the space IDs exist
    if (fromId == bytes16(0) || toId == bytes16(0)) revert SpaceNotRegistered();

    // If msg.sender is not the from
    // Then pass the to, action, topic, data, and signature to the space
    if (msg.sender != _from) ISpace(_from).verify(_to, _action, _topic, _data, _signature);

    // No fetch or write with permissionless actions
    if (permissionlessActions[_action]) {
      emit Action(fromId, toId, _action, _topic, _data);
    } else {
      // Fetch future output variable and update `_topic` for emission if relevant
      if (msg.sender != _to) _topic = ISpace(_to).fetch(_action, _topic, _data);

      emit Action(fromId, toId, _action, _topic, _data);

      // If msg.sender is not the to
      // Then pass the from, action, topic, and data to the space
      if (msg.sender != _to) ISpace(_to).write(_from, _action, _topic, _data);
    }
  }

  /// @inheritdoc ISpaceRegistry
  function registerSpaceId() external virtual {
    // Account must not be registered
    if (addressToSpaceId[msg.sender] != bytes16(0)) revert SpaceAlreadyRegistered();

    bytes16 spaceId = generateSpaceId(msg.sender, _spaceIdNonce++);

    addressToSpaceId[msg.sender] = spaceId;
    spaceIdToAddress[spaceId] = msg.sender;

    emit Action(bytes16(0), spaceId, ActionsConstants.SPACE_ID_REGISTERED, bytes32(bytes20(msg.sender)), '');
  }

  /// @inheritdoc ISpaceRegistry
  function proposeSpaceMigration(address _newAccount) external virtual {
    // Must be called by the space itself
    bytes16 spaceId = addressToSpaceId[msg.sender];
    if (spaceId == bytes16(0)) revert InvalidCaller();

    spaceIdToProposedAddress[spaceId] = _newAccount;
  }

  /// @inheritdoc ISpaceRegistry
  function acceptSpaceMigration(bytes16 _spaceId) external virtual {
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

    emit Action(_spaceId, _spaceId, ActionsConstants.SPACE_ID_MIGRATED, bytes32(bytes20(msg.sender)), '');
  }

  /// @inheritdoc ISpaceRegistry
  function setPermissionlessAction(bytes32 _action, bool _set) external virtual onlyOwner {
    permissionlessActions[_action] = _set;
  }

  /// @inheritdoc ISpaceRegistry
  function generateSpaceId(address _account, uint256 _nonce) public view virtual returns (bytes16 _spaceId) {
    _spaceId = bytes16(keccak256(abi.encodePacked('grc20.space', _account, _nonce, block.chainid)));
  }

  /// @inheritdoc ISemver
  function version() public pure virtual returns (string memory _version) {
    _version = '1.0.0';
  }

  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}
}
