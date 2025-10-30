// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {IEmitter} from 'interfaces/IEmitter.sol';

interface ISpaceRegistry is IEmitter {
  // Events

  /// @notice Emitted when the SpaceRegistry is initialized
  /// @param daoFactory The address of the DAOFactory contract
  /// @param owner The address of the owner
  event SpaceRegistryInitialized(address daoFactory, address owner);

  /// @notice Emitted when a new space is created
  /// @param spaceId The unique identifier of the created space
  /// @param dao The address of the DAO contract deployed for this space
  /// @param creator The address that created the space
  event SpaceRegistrySpaceCreated(bytes16 indexed spaceId, address indexed dao, address indexed creator);

  /// @notice Emitted when a space migrates from one DAO contract to another while keeping its space ID
  /// @param spaceId The space ID that remains constant through the migration
  /// @param oldDao The address of the previous DAO contract
  /// @param newDao The address of the new DAO contract
  event SpaceRegistrySpaceMigrated(bytes16 indexed spaceId, address indexed oldDao, address indexed newDao);

  // Errors

  /// @notice Thrown when attempting to initialize with a zero address
  error InvalidZeroAddress();

  /// @notice Thrown when the caller is not authorized for the operation
  error InvalidCaller();

  /// @notice Thrown when trying to register or migrate a space with an address that's already assigned to another space
  error SpaceAlreadyRegistered();

  // Functions

  /// @notice Maps each unique space ID to its current address
  /// @param _spaceId The ID of the space
  /// @return account The address of the space
  function spaceIdToAddress(bytes16 _spaceId) external view returns (address account);

  /// @notice Reverse mapping: address to its space ID
  /// @param _account The address of the space
  /// @return spaceId The ID of the space
  function addressToSpaceId(address _account) external view returns (bytes16 spaceId);

  /// @notice Initializes the SpaceRegistry contract
  /// @param _owner The address that will own this registry contract
  function initialize(address _owner) external;

  /**
   * @notice Generalized entry point for all users across all spaces
   * @param _from The space contract on which to call the verify function
   * @param _to The space contract on which to call the write function
   * @param _action The action that is passed to the space contract
   * @param _topic The topic that is passed to the space contract
   * @param _data The arbitrary data for space contract execution
   * @param _signature The signature for account verification
   */
  function enter(
    address _from,
    address _to,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external;

  /**
   * @notice Creates a new space by registering a space ID for a given address
   * @param _account The address to register a space ID for
   */
  function registerSpaceId(address _account) external;

  /**
   * @notice Allows an address to migrate its space ID to a new address
   * @dev Can only be called by an existing address in the registry
   * @param _newAccount The new address of the space
   */
  function migrateSpaceAddress(address _newAccount) external;

  /**
   * @notice Generates a space ID for a given address and nonce
   * @param _account The address to generate a space ID for
   * @param _nonce The nonce to generate a space ID for
   * @return spaceId The ID of the space that was generated
   */
  function generateSpaceId(address _account, uint256 _nonce) external view returns (bytes16 spaceId);
}
