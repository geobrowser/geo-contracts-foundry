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
 * @custom:security WARNING: This contract has not been audited, may contain bugs, and should not be used to hold funds.
 */
contract SpaceRegistry is UUPSUpgradeable, OwnableUpgradeable, ISpaceRegistry {
  /**
   * @notice The storage location of the space registry contract
   * @custom:storage-location erc7201:geo.storage.SpaceRegistry
   * @dev Computed with: keccak256(abi.encode(uint256(keccak256("geo.storage.SpaceRegistry")) - 1)) & ~bytes32(uint256(0xff))
   */
  bytes32 internal constant _SPACE_REGISTRY_STORAGE_LOCATION =
    0xa1b85c99b52a518d0806b31f4568cbd8c3970d0ca846714c1d12666d5d19bc00;

  /**
   * @notice Constructor
   * @custom:oz-upgrades-unsafe-allow constructor
   */
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc ISpaceRegistry
  function initialize(bytes calldata _initializerData) external virtual initializer {
    // Decode initializer data
    address _owner = abi.decode(_initializerData, (address));

    __Ownable_init(_owner);

    _registerSpaceId(address(this), typeId(), abi.encode(version()));

    _permissionlessActionAdded(ActionsConstants.UPVOTED);
    _permissionlessActionAdded(ActionsConstants.DOWNVOTED);
    _permissionlessActionAdded(ActionsConstants.UNVOTED);
    _permissionlessActionAdded(ActionsConstants.COMMENTED);
  }

  /// @inheritdoc ISpaceRegistry
  function enter(
    bytes16 _fromSpaceId,
    bytes16 _toSpaceId,
    bytes32 _action,
    bytes32 _subject,
    bytes calldata _data,
    bytes calldata _signature
  ) external virtual {
    if (!activeSpaceIds(_fromSpaceId) || !activeSpaceIds(_toSpaceId)) revert SpaceNotActive();

    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    address _fromSpace = $_.spaceIdToAddress[_fromSpaceId];
    address _toSpace = $_.spaceIdToAddress[_toSpaceId];

    // If msg.sender is not the from space
    // Then pass the msg.sender, to space ID, action, subject, data, and signature to the from space
    if (msg.sender != _fromSpace) {
      if (_fromSpace.code.length == 0) revert InvalidCaller();
      ISpace(_fromSpace).verify(msg.sender, _toSpaceId, _action, _subject, _data, _signature);
    }

    // No fetch or write with permissionless actions
    if ($_.permissionlessActions[_action]) {
      emit Action(_fromSpaceId, _toSpaceId, _action, _subject, _data);
    } else {
      // Fetch future output variable and update `_subject` for emission if relevant
      if (msg.sender != _toSpace) _subject = ISpace(_toSpace).fetch(_action, _subject, _data);

      emit Action(_fromSpaceId, _toSpaceId, _action, _subject, _data);

      // If msg.sender is not the to space
      // Then pass the from space ID, action, subject, and data to the to space
      if (msg.sender != _toSpace) ISpace(_toSpace).write(_fromSpaceId, _action, _subject, _data);
    }
  }

  /// @inheritdoc ISpaceRegistry
  function registerSpaceId(bytes32 _type, bytes memory _version) external virtual returns (bytes16 _spaceId) {
    _spaceId = _registerSpaceId(msg.sender, _type, _version);
  }

  /// @inheritdoc ISpaceRegistry
  function archiveSpaceId() external virtual {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    // Space must first be registered and not archived
    bytes16 _spaceId = $_.addressToSpaceId[msg.sender];
    if (_spaceId == bytes16(0)) revert SpaceNotRegistered();
    if ($_.archivedSpaceIds[_spaceId]) revert SpaceAlreadyArchived();

    $_.archivedSpaceIds[_spaceId] = true;

    emit Action(_spaceId, _spaceId, ActionsConstants.SPACE_ID_ARCHIVED, bytes32(bytes20(msg.sender)), '');
  }

  /// @inheritdoc ISpaceRegistry
  function recoverSpaceId() external virtual {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    // Space must first be registered and archived
    bytes16 _spaceId = $_.addressToSpaceId[msg.sender];
    if (_spaceId == bytes16(0)) revert SpaceNotRegistered();
    if (!$_.archivedSpaceIds[_spaceId]) revert SpaceNotArchived();

    $_.archivedSpaceIds[_spaceId] = false;

    emit Action(_spaceId, _spaceId, ActionsConstants.SPACE_ID_RECOVERED, bytes32(bytes20(msg.sender)), '');
  }

  /// @inheritdoc ISpaceRegistry
  function clearSpaceId() external virtual {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    // Space must first be registered and archived
    bytes16 _spaceId = $_.addressToSpaceId[msg.sender];
    if (_spaceId == bytes16(0)) revert SpaceNotRegistered();
    if (!$_.archivedSpaceIds[_spaceId]) revert SpaceNotArchived();

    // Clear all mappings
    $_.addressToSpaceId[msg.sender] = bytes16(0);
    $_.spaceIdToAddress[_spaceId] = address(0);
    $_.spaceIdToProposedAddress[_spaceId] = address(0);
    $_.archivedSpaceIds[_spaceId] = false;

    emit Action(_spaceId, bytes16(0), ActionsConstants.SPACE_ID_CLEARED, bytes32(bytes20(msg.sender)), '');
  }

  /// @inheritdoc ISpaceRegistry
  function proposeSpaceMigration(address _newAccount) external virtual {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    // Must be called by the space itself
    bytes16 _spaceId = $_.addressToSpaceId[msg.sender];
    if (_spaceId == bytes16(0)) revert SpaceNotRegistered();
    // Must not be archived
    if ($_.archivedSpaceIds[_spaceId]) revert SpaceAlreadyArchived();

    $_.spaceIdToProposedAddress[_spaceId] = _newAccount;

    emit Action(_spaceId, _spaceId, ActionsConstants.SPACE_ID_MIGRATION_PROPOSED, bytes32(bytes20(_newAccount)), '');
  }

  /// @inheritdoc ISpaceRegistry
  function acceptSpaceMigration(bytes16 _spaceId, bytes32 _type, bytes calldata _version) external virtual {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    // Must be called by the proposed space itself
    if ($_.spaceIdToProposedAddress[_spaceId] != msg.sender) revert InvalidCaller();
    // New address must not be registered
    if ($_.addressToSpaceId[msg.sender] != bytes16(0)) revert SpaceAlreadyRegistered();
    // Space must not be archived
    if ($_.archivedSpaceIds[_spaceId]) revert SpaceAlreadyArchived();

    // Update the bi-directional mappings and reset the proposal
    address _oldAccount = $_.spaceIdToAddress[_spaceId];
    $_.spaceIdToProposedAddress[_spaceId] = address(0);
    $_.spaceIdToAddress[_spaceId] = msg.sender;
    $_.addressToSpaceId[_oldAccount] = bytes16(0);
    $_.addressToSpaceId[msg.sender] = _spaceId;

    emit Action(_spaceId, _spaceId, ActionsConstants.SPACE_ID_MIGRATED, bytes32(bytes20(msg.sender)), '');
    if (_type != bytes32(0)) emit Action(_spaceId, _spaceId, ActionsConstants.SPACE_TYPE_DECLARED, _type, _version);
  }

  /// @inheritdoc ISpaceRegistry
  function overrideSpaceId(address _account, bytes16 _spaceId) external virtual onlyOwner {
    if (_account == address(0) || _spaceId == bytes16(0)) revert OverrideZero();
    if (_account == address(this)) revert InvalidAccount();

    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();

    // Clear old relationship
    address _oldAccount = $_.spaceIdToAddress[_spaceId];
    bytes16 _oldSpaceId = $_.addressToSpaceId[_account];
    $_.addressToSpaceId[_oldAccount] = bytes16(0);
    $_.spaceIdToAddress[_oldSpaceId] = address(0);

    // Add new relationship
    $_.addressToSpaceId[_account] = _spaceId;
    $_.spaceIdToAddress[_spaceId] = _account;
    $_.spaceIdToProposedAddress[_spaceId] = address(0);
    $_.archivedSpaceIds[_spaceId] = false;

    // Action event emissions
    emit Action(_oldSpaceId, _spaceId, ActionsConstants.SPACE_ID_OVERRIDDEN, bytes32(bytes20(_account)), '');
  }

  /// @inheritdoc ISpaceRegistry
  function overrideAction(
    bytes16[] calldata _fromSpaceIds,
    bytes16[] calldata _toSpaceIds,
    bytes32[] calldata _actions,
    bytes32[] calldata _subjects,
    bytes[] calldata _datas
  ) external virtual onlyOwner {
    uint256 _length = _fromSpaceIds.length;
    if (
      _length != _toSpaceIds.length || _length != _actions.length || _length != _subjects.length
        || _length != _datas.length
    ) revert InvalidActionArraysLength();

    // Emit arbitrary Action events for indexer consistency
    for (uint256 _i; _i < _length; _i++) {
      emit Action(_fromSpaceIds[_i], _toSpaceIds[_i], _actions[_i], _subjects[_i], _datas[_i]);
    }
  }

  /// @inheritdoc ISpaceRegistry
  function setPermissionlessAction(bytes32 _action, bool _isPermissionless) external virtual onlyOwner {
    _isPermissionless ? _permissionlessActionAdded(_action) : _permissionlessActionRemoved(_action);
  }

  /// @inheritdoc ISpaceRegistry
  function generateSpaceId(address _account, uint256 _nonce) public view virtual returns (bytes16 _spaceId) {
    bytes32 _hash = keccak256(abi.encodePacked('grc20.space', _account, _nonce, block.chainid));
    _hash = _hash & ~(bytes32(uint256(0xf0)) << 200) | (bytes32(uint256(0x40)) << 200);
    _spaceId = bytes16(_hash & ~(bytes32(uint256(0xc0)) << 184) | (bytes32(uint256(0x80)) << 184));
  }

  /// @inheritdoc ISpaceRegistry
  function spaceIdToAddress(bytes16 _spaceId) public view returns (address _account) {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    _account = $_.spaceIdToAddress[_spaceId];
  }

  /// @inheritdoc ISpaceRegistry
  function spaceIdToProposedAddress(bytes16 _spaceId) public view returns (address _account) {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    _account = $_.spaceIdToProposedAddress[_spaceId];
  }

  /// @inheritdoc ISpaceRegistry
  function addressToSpaceId(address _account) public view returns (bytes16 _spaceId) {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    _spaceId = $_.addressToSpaceId[_account];
  }

  /// @inheritdoc ISpaceRegistry
  function permissionlessActions(bytes32 _action) public view returns (bool _isPermissionless) {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    _isPermissionless = $_.permissionlessActions[_action];
  }

  /// @inheritdoc ISpaceRegistry
  function registeredSpaceIds(bytes16 _spaceId) public view returns (bool _isRegistered) {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    _isRegistered = $_.spaceIdToAddress[_spaceId] != address(0);
  }

  /// @inheritdoc ISpaceRegistry
  function registeredSpaceAddresses(address _account) public view returns (bool _isRegistered) {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    _isRegistered = $_.addressToSpaceId[_account] != bytes16(0);
  }

  /// @inheritdoc ISpaceRegistry
  function archivedSpaceIds(bytes16 _spaceId) public view returns (bool _isArchived) {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    _isArchived = $_.archivedSpaceIds[_spaceId];
  }

  /// @inheritdoc ISpaceRegistry
  function activeSpaceIds(bytes16 _spaceId) public view returns (bool _isActive) {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    _isActive = $_.spaceIdToAddress[_spaceId] != address(0) && !$_.archivedSpaceIds[_spaceId];
  }

  /// @inheritdoc ISemver
  function typeId() public pure virtual returns (bytes32 _type) {
    _type = keccak256(bytes(name()));
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
  function _authorizeUpgrade(address _newImplementation) internal virtual override onlyOwner {}

  /**
   * @notice Registers an account as a space in the registry
   * @param _account The account address to register
   * @param _type The type of space being registered (optional)
   * @param _version The version of the space implementation (optional)
   * @return _spaceId The newly generated space ID
   */
  function _registerSpaceId(
    address _account,
    bytes32 _type,
    bytes memory _version
  ) internal virtual returns (bytes16 _spaceId) {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    // Account must not be registered
    if ($_.addressToSpaceId[_account] != bytes16(0)) revert SpaceAlreadyRegistered();

    _spaceId = generateSpaceId(_account, $_._spaceIdNonce++);

    $_.addressToSpaceId[_account] = _spaceId;
    $_.spaceIdToAddress[_spaceId] = _account;

    emit Action(bytes16(0), _spaceId, ActionsConstants.SPACE_ID_REGISTERED, bytes32(bytes20(_account)), '');
    if (_type != bytes32(0)) emit Action(_spaceId, _spaceId, ActionsConstants.SPACE_TYPE_DECLARED, _type, _version);
  }

  /**
   * @notice Adds a permissionless action to the registry
   * @param _action The action identifier
   */
  function _permissionlessActionAdded(bytes32 _action) internal virtual {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    $_.permissionlessActions[_action] = true;

    emit Action(bytes16(0), bytes16(0), ActionsConstants.PERMISSIONLESS_ACTION_ADDED, _action, '');
  }

  /**
   * @notice Removes a permissionless action from the registry
   * @param _action The action identifier
   */
  function _permissionlessActionRemoved(bytes32 _action) internal virtual {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    $_.permissionlessActions[_action] = false;

    emit Action(bytes16(0), bytes16(0), ActionsConstants.PERMISSIONLESS_ACTION_REMOVED, _action, '');
  }

  /**
   * @notice Returns the space registry contract storage
   * @return $_ The storage of the space registry contract
   * @custom:storage-location erc7201:geo.storage.SpaceRegistry
   */
  function _getSpaceRegistryStorage() internal pure returns (SpaceRegistryStorage storage $_) {
    assembly {
      $_.slot := _SPACE_REGISTRY_STORAGE_LOCATION
    }
  }
}
