// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

import 'src/ActionsConstants.sol' as ActionsConstants;

/**
 * @title SpaceRegistry
 * @notice Central registry for managing spaces
 * @dev This contract serves as the entry point for creating new spaces
 *      Each space has a unique ID that maps to an address
 *      Spaces can migrate to new addresses while keeping their ID
 */
contract SpaceRegistry is UUPSUpgradeable, OwnableUpgradeable, ISpaceRegistry {
  /**
   * @notice The storage location of the space registry contract
   * @custom:storage-location erc7201:geo.storage.SpaceRegistry
   */
  bytes32 internal constant _SPACE_REGISTRY_STORAGE_LOCATION =
    0xa1b85c99b52a518d0806b31f4568cbd8c3970d0ca846714c1d12666d5d19bc00;

  /// @notice Constructor
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc ISpaceRegistry
  function initialize(bytes calldata _initializerData) external virtual initializer {
    address _owner = abi.decode(_initializerData, (address));
    __Ownable_init(_owner);
    _permissionlessActionAdded(ActionsConstants.UPVOTED);
    _permissionlessActionAdded(ActionsConstants.DOWNVOTED);
    _permissionlessActionAdded(ActionsConstants.UNVOTED);
    _permissionlessActionAdded(ActionsConstants.COMMENTED);
    _registerSpaceId(address(this), typeId(), abi.encode(version()));
  }

  /// @inheritdoc ISpaceRegistry
  function enter(
    bytes16 _fromSpaceId,
    bytes16 _toSpaceId,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external virtual {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();
    address _fromSpace = $.spaceIdToAddress[_fromSpaceId];
    address _toSpace = $.spaceIdToAddress[_toSpaceId];
    if (_fromSpace == address(0) || _toSpace == address(0)) revert SpaceNotRegistered();

    // If msg.sender is not the from space
    // Then pass the to space ID, action, topic, data, and signature to the from space
    if (msg.sender != _fromSpace) ISpace(_fromSpace).verify(_toSpaceId, _action, _topic, _data, _signature);

    // No fetch or write with permissionless actions
    if ($.permissionlessActions[_action]) {
      emit Action(_fromSpaceId, _toSpaceId, _action, _topic, _data);
    } else {
      // Fetch future output variable and update `_topic` for emission if relevant
      if (msg.sender != _toSpace) _topic = ISpace(_toSpace).fetch(_action, _topic, _data);

      emit Action(_fromSpaceId, _toSpaceId, _action, _topic, _data);

      // If msg.sender is not the to space
      // Then pass the from space ID, action, topic, and data to the to space
      if (msg.sender != _toSpace) ISpace(_toSpace).write(_fromSpaceId, _action, _topic, _data);
    }
  }

  /// @inheritdoc ISpaceRegistry
  function registerSpaceId(bytes32 _type, bytes memory _version) external virtual returns (bytes16 _spaceId) {
    _spaceId = _registerSpaceId(msg.sender, _type, _version);
  }

  /// @inheritdoc ISpaceRegistry
  function clearSpaceId() external virtual {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();

    // Space must first be registered
    bytes16 _spaceId = $.addressToSpaceId[msg.sender];
    if (_spaceId == bytes16(0)) revert SpaceNotRegistered();

    $.addressToSpaceId[msg.sender] = bytes16(0);
    $.spaceIdToAddress[_spaceId] = address(0);
    $.spaceIdToProposedAddress[_spaceId] = address(0);

    emit Action(_spaceId, bytes16(0), ActionsConstants.SPACE_ID_CLEARED, bytes32(bytes20(msg.sender)), '');
  }

  /// @inheritdoc ISpaceRegistry
  function proposeSpaceMigration(address _newAccount) external virtual {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();

    // Must be called by the space itself
    bytes16 _spaceId = $.addressToSpaceId[msg.sender];
    if (_spaceId == bytes16(0)) revert InvalidCaller();

    $.spaceIdToProposedAddress[_spaceId] = _newAccount;

    emit Action(_spaceId, _spaceId, ActionsConstants.SPACE_ID_MIGRATION_PROPOSED, bytes32(bytes20(_newAccount)), '');
  }

  /// @inheritdoc ISpaceRegistry
  function acceptSpaceMigration(bytes16 _spaceId, bytes32 _type, bytes calldata _version) external virtual {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();

    // Must be called by the proposed space itself
    if ($.spaceIdToProposedAddress[_spaceId] != msg.sender) revert InvalidCaller();

    // New address must not be registered
    if ($.addressToSpaceId[msg.sender] != bytes16(0)) revert SpaceAlreadyRegistered();

    address _oldAccount = $.spaceIdToAddress[_spaceId];

    // Update the bi-directional mappings and reset the proposal
    $.spaceIdToProposedAddress[_spaceId] = address(0);
    $.spaceIdToAddress[_spaceId] = msg.sender;
    $.addressToSpaceId[_oldAccount] = bytes16(0);
    $.addressToSpaceId[msg.sender] = _spaceId;

    emit Action(_spaceId, _spaceId, ActionsConstants.SPACE_ID_MIGRATED, bytes32(bytes20(msg.sender)), '');
    if (_type != bytes32(0)) emit Action(_spaceId, _spaceId, ActionsConstants.SPACE_TYPE_DECLARED, _type, _version);
  }

  /// @inheritdoc ISpaceRegistry
  function setPermissionlessAction(bytes32 _action, bool _isPermissionless) external virtual onlyOwner {
    (_isPermissionless) ? _permissionlessActionAdded(_action) : _permissionlessActionRemoved(_action);
  }

  /// @inheritdoc ISpaceRegistry
  function generateSpaceId(address _account, uint256 _nonce) public view virtual returns (bytes16 _spaceId) {
    _spaceId = bytes16(keccak256(abi.encodePacked('grc20.space', _account, _nonce, block.chainid)));
  }

  /// @inheritdoc ISpaceRegistry
  function spaceIdToAddress(bytes16 _spaceId) public view returns (address _account) {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();
    _account = $.spaceIdToAddress[_spaceId];
  }

  /// @inheritdoc ISpaceRegistry
  function spaceIdToProposedAddress(bytes16 _spaceId) public view returns (address _account) {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();
    _account = $.spaceIdToProposedAddress[_spaceId];
  }

  /// @inheritdoc ISpaceRegistry
  function addressToSpaceId(address _account) public view returns (bytes16 _spaceId) {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();
    _spaceId = $.addressToSpaceId[_account];
  }

  /// @inheritdoc ISpaceRegistry
  function permissionlessActions(bytes32 _action) public view returns (bool _isPermissionless) {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();
    _isPermissionless = $.permissionlessActions[_action];
  }

  /// @inheritdoc ISemver
  function typeId() public pure virtual returns (bytes32 _type) {
    _type = keccak256(bytes('SPACE_REGISTRY'));
  }

  /// @inheritdoc ISemver
  function name() public pure virtual returns (string memory _name) {
    _name = 'SPACE_REGISTRY';
  }

  /// @inheritdoc ISemver
  function version() public pure virtual returns (string memory _version) {
    _version = '1.0.0';
  }

  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

  /**
   * @notice Registers an account as a space in the registry
   * @param _account The account address to register
   * @param _type The type of space being registered (optional)
   * @param _version The version of the space implementation (optional)
   * @return _spaceId The newly generated space id
   */
  function _registerSpaceId(
    address _account,
    bytes32 _type,
    bytes memory _version
  ) internal virtual returns (bytes16 _spaceId) {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();

    // Account must not be registered
    if ($.addressToSpaceId[_account] != bytes16(0)) revert SpaceAlreadyRegistered();

    _spaceId = generateSpaceId(_account, $._spaceIdNonce++);

    $.addressToSpaceId[_account] = _spaceId;
    $.spaceIdToAddress[_spaceId] = _account;

    emit Action(bytes16(0), _spaceId, ActionsConstants.SPACE_ID_REGISTERED, bytes32(bytes20(_account)), '');
    if (_type != bytes32(0)) emit Action(_spaceId, _spaceId, ActionsConstants.SPACE_TYPE_DECLARED, _type, _version);
  }

  /**
   * @notice Adds a permissionless action to the registry
   * @param _action The action identifier
   */
  function _permissionlessActionAdded(bytes32 _action) internal virtual {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();
    $.permissionlessActions[_action] = true;
    emit Action(bytes16(0), bytes16(0), ActionsConstants.PERMISSIONLESS_ACTION_ADDED, _action, '');
  }

  /**
   * @notice Removes a permissionless action from the registry
   * @param _action The action identifier
   */
  function _permissionlessActionRemoved(bytes32 _action) internal virtual {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();
    $.permissionlessActions[_action] = false;
    emit Action(bytes16(0), bytes16(0), ActionsConstants.PERMISSIONLESS_ACTION_REMOVED, _action, '');
  }

  /**
   * @notice Returns the space registry contract storage
   * @return $ The storage of the space registry contract
   * @custom:storage-location erc7201:geo.storage.SpaceRegistry
   */
  function _getSpaceRegistryStorage() internal pure returns (SpaceRegistryStorage storage $) {
    assembly {
      $.slot := _SPACE_REGISTRY_STORAGE_LOCATION
    }
  }
}
