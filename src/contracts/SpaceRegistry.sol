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
  }

  /// @inheritdoc ISpaceRegistry
  function enter(
    address _fromSpace,
    address _toSpace,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external virtual {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();
    bytes16 fromSpaceId = $.addressToSpaceId[_fromSpace];
    bytes16 toSpaceId = $.addressToSpaceId[_toSpace];
    if (fromSpaceId == bytes16(0) || toSpaceId == bytes16(0)) revert SpaceNotRegistered();

    // If msg.sender is not the from space
    // Then pass the to space, action, topic, data, and signature to the from space
    if (msg.sender != _fromSpace) ISpace(_fromSpace).verify(_toSpace, _action, _topic, _data, _signature);

    // No fetch or write with permissionless actions
    if ($.permissionlessActions[_action]) {
      emit Action(fromSpaceId, toSpaceId, _action, _topic, _data);
    } else {
      // Fetch future output variable and update `_topic` for emission if relevant
      if (msg.sender != _toSpace) _topic = ISpace(_toSpace).fetch(_action, _topic, _data);

      emit Action(fromSpaceId, toSpaceId, _action, _topic, _data);

      // If msg.sender is not the to space
      // Then pass the from space, action, topic, and data to the to space
      if (msg.sender != _toSpace) ISpace(_toSpace).write(_fromSpace, _action, _topic, _data);
    }
  }

  /// @inheritdoc ISpaceRegistry
  function registerSpaceId() external virtual {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();

    // Account must not be registered
    if ($.addressToSpaceId[msg.sender] != bytes16(0)) revert SpaceAlreadyRegistered();

    bytes16 spaceId = generateSpaceId(msg.sender, $._spaceIdNonce++);

    $.addressToSpaceId[msg.sender] = spaceId;
    $.spaceIdToAddress[spaceId] = msg.sender;

    emit Action(bytes16(0), spaceId, ActionsConstants.SPACE_ID_REGISTERED, bytes32(bytes20(msg.sender)), '');
  }

  /// @inheritdoc ISpaceRegistry
  function clearSpaceId() external virtual {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();

    bytes16 spaceId = $.addressToSpaceId[msg.sender];
    $.addressToSpaceId[msg.sender] = bytes16(0);
    $.spaceIdToAddress[spaceId] = address(0);
    $.spaceIdToProposedAddress[spaceId] = address(0);

    emit Action(spaceId, bytes16(0), ActionsConstants.SPACE_ID_CLEARED, bytes32(bytes20(msg.sender)), '');
  }

  /// @inheritdoc ISpaceRegistry
  function proposeSpaceMigration(address _newAccount) external virtual {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();

    // Must be called by the space itself
    bytes16 spaceId = $.addressToSpaceId[msg.sender];
    if (spaceId == bytes16(0)) revert InvalidCaller();

    $.spaceIdToProposedAddress[spaceId] = _newAccount;
  }

  /// @inheritdoc ISpaceRegistry
  function acceptSpaceMigration(bytes16 _spaceId) external virtual {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();

    // Must be called by the proposed space itself
    if ($.spaceIdToProposedAddress[_spaceId] != msg.sender) revert InvalidCaller();

    // New address must not be registered
    if ($.addressToSpaceId[msg.sender] != bytes16(0)) revert SpaceAlreadyRegistered();

    address oldAccount = $.spaceIdToAddress[_spaceId];

    // Update the bi-directional mappings and reset the proposal
    $.spaceIdToProposedAddress[_spaceId] = address(0);
    $.spaceIdToAddress[_spaceId] = msg.sender;
    $.addressToSpaceId[oldAccount] = bytes16(0);
    $.addressToSpaceId[msg.sender] = _spaceId;

    emit Action(_spaceId, _spaceId, ActionsConstants.SPACE_ID_MIGRATED, bytes32(bytes20(msg.sender)), '');
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
  function version() public pure virtual returns (string memory _version) {
    _version = '1.0.0';
  }

  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

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
