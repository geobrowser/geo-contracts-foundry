// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title ISpaceRegistry
 * @notice Central registry for managing spaces
 */
interface ISpaceRegistry is ISemver {
  /**
   * @notice The storage struct of the space registry contract
   * @param spaceIdToAddress Maps each unique space ID to its current address
   * @param spaceIdToProposedAddress Maps each unique space ID to its proposed address
   * @param addressToSpaceId Reverse mapping: address to its space ID
   * @param permissionlessActions Records each permissionless action
   * @param _spaceIdNonce The nonce used to generate a space ID for registration
   * @custom:storage-location erc7201:geo.storage.SpaceRegistry
   */
  struct SpaceRegistryStorage {
    mapping(bytes16 _spaceId => address _account) spaceIdToAddress;
    mapping(bytes16 _spaceId => address _account) spaceIdToProposedAddress;
    mapping(address _account => bytes16 _spaceId) addressToSpaceId;
    mapping(bytes32 _action => bool _isPermissionless) permissionlessActions;
    uint256 _spaceIdNonce;
  }

  /**
   * @notice Emitted when a user calls the enter function
   * @param fromSpaceId The from space ID involved
   * @param toSpaceId The to space ID involved
   * @param action An action, which is passed to the space contract
   * @param topic A topic, which is passed to the space contract
   * @param data Some extra arbitrary data that may be used for space contract execution
   */
  event Action(
    bytes16 indexed fromSpaceId, bytes16 indexed toSpaceId, bytes32 indexed action, bytes32 indexed topic, bytes data
  ) anonymous;

  /// @notice Thrown when the caller is not authorized for the operation
  error InvalidCaller();

  /// @notice Thrown when trying to enter a space with an address that's not assigned to a space
  error SpaceNotRegistered();

  /// @notice Thrown when trying to register or migrate a space with an address that's already assigned to another space
  error SpaceAlreadyRegistered();

  /**
   * @notice Maps each unique space ID to its current address
   * @param _spaceId The ID of the space
   * @return _account The current address of the space
   */
  function spaceIdToAddress(bytes16 _spaceId) external view returns (address _account);

  /**
   * @notice Maps each unique space ID to its proposed address
   * @param _spaceId The ID of the space
   * @return _account The proposed address of the space
   */
  function spaceIdToProposedAddress(bytes16 _spaceId) external view returns (address _account);

  /**
   * @notice Reverse mapping: address to its space ID
   * @param _account The address of the space
   * @return _spaceId The ID of the space
   */
  function addressToSpaceId(address _account) external view returns (bytes16 _spaceId);

  /**
   * @notice Records each permissionless action
   * @param _action The action identifier
   * @return _isPermissionless The boolean of whether or not the action is permissionless
   */
  function permissionlessActions(bytes32 _action) external view returns (bool _isPermissionless);

  /**
   * @notice Initializes the contract
   * @param _initializerData The encoded initializer data:
   *        _owner The address of the owner
   */
  function initialize(bytes calldata _initializerData) external;

  /**
   * @notice Generalized entry point for all users across all spaces
   * @param _fromSpaceId The space ID on which to call the verify function
   * @param _toSpaceId The space ID on which to call the write function
   * @param _action The action that is passed to the space contract
   * @param _topic The topic that is passed to the space contract
   * @param _data The arbitrary data for space contract execution
   * @param _signature The signature for account verification
   */
  function enter(
    bytes16 _fromSpaceId,
    bytes16 _toSpaceId,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external;

  /**
   * @notice Creates a new space by registering a space ID for the caller address
   * @param _type The type of space being registered (optional)
   * @param _version The version of the space implementation (optional)
   * @return _spaceId The newly generated space id
   */
  function registerSpaceId(bytes32 _type, bytes calldata _version) external returns (bytes16 _spaceId);

  /**
   * @notice Clears a space ID from the registry and disconnects it from any address
   */
  function clearSpaceId() external;

  /**
   * @notice Allows an address to propose to migrate its space ID to a new address
   * @dev Can only be called by an existing address in the registry
   * @param _newAccount The proposed address of the space
   */
  function proposeSpaceMigration(address _newAccount) external;

  /**
   * @notice Allows an address to accept to migrate a space ID to itself
   * @dev Can only be called by an existing proposed address in the registry
   * @param _spaceId The ID of the space
   * @param _type The type of space being registered (optional)
   * @param _version The version of the space implementation (optional)
   */
  function acceptSpaceMigration(bytes16 _spaceId, bytes32 _type, bytes calldata _version) external;

  /**
   * @notice Allows the owner to add or remove permissionless actions
   * @param _action The action identifier
   * @param _set The boolean of whether or not the action is permissionless (true if it is, no otherwise)
   * @dev Permissionless actions are those where, even if the caller is not the toSpace, fetch and write do not occur
   */
  function setPermissionlessAction(bytes32 _action, bool _set) external;

  /**
   * @notice Generates a space ID for a given address and nonce
   * @param _account The address to generate a space ID for
   * @param _nonce The nonce to generate a space ID for
   * @return _spaceId The ID of the space that was generated
   */
  function generateSpaceId(address _account, uint256 _nonce) external view returns (bytes16 _spaceId);
}
