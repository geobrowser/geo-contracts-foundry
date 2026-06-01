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
   * @param archivedSpaceIds Maps each space ID to whether it has been archived
   * @param addressToSpaceId Reverse mapping: address to its space ID
   * @param permissionlessActions Records each permissionless action
   * @param _spaceIdNonce The nonce used to generate a space ID for registration
   * @param paymentManager Arbitrum PaymentManager proxy for cross-chain setPayer messages
   * @custom:storage-location erc7201:geo.storage.SpaceRegistry
   */
  struct SpaceRegistryStorage {
    mapping(bytes16 _spaceId => address _account) spaceIdToAddress;
    mapping(bytes16 _spaceId => address _account) spaceIdToProposedAddress;
    mapping(bytes16 _spaceId => bool _isArchived) archivedSpaceIds;
    mapping(address _account => bytes16 _spaceId) addressToSpaceId;
    mapping(bytes32 _action => bool _isPermissionless) permissionlessActions;
    uint256 _spaceIdNonce;
    address paymentManager;
  }

  /**
   * @notice Emitted when a user calls the enter function, and for other registry flows
   * @param fromSpaceId The from space ID involved
   * @param toSpaceId The to space ID involved
   * @param action An action, which is passed to the space contract
   * @param subject A subject, which is passed to the space contract
   * @param data Some extra arbitrary data that may be used for space contract execution
   */
  event Action(
    bytes16 indexed fromSpaceId, bytes16 indexed toSpaceId, bytes32 indexed action, bytes32 indexed subject, bytes data
  ) anonymous;

  /// @notice Thrown when overrideAction is called with mismatched _fromSpaceIds, _toSpaceIds, _actions, _subjects, _datas lengths
  error InvalidActionArraysLength();

  /// @notice Thrown when the caller is not authorized for the operation
  error InvalidCaller();

  /// @notice Thrown when trying to enter a space with an address that's not assigned to a space
  error SpaceNotRegistered();

  /// @notice Thrown when trying to register or migrate a space with an address that's already assigned to another space
  error SpaceAlreadyRegistered();

  /// @notice Thrown when trying to recover a space ID that is not archived
  error SpaceNotArchived();

  /// @notice Thrown when trying to archive a space ID that is already archived
  error SpaceAlreadyArchived();

  /// @notice Thrown when trying to enter with a space that is not active (not registered or archived)
  error SpaceNotActive();

  /// @notice Thrown when overrideSpaceId is called with either the zero address or space id
  error OverrideZero();

  /// @notice Thrown when overrideSpaceId targets this registry contract's own address
  error InvalidAccount();

  /// @notice Thrown when setL2IncentivesPayer is called before paymentManager is configured
  error PaymentManagerNotSet();

  /// @notice Thrown when setL2IncentivesPayer is called with the zero address payer
  error InvalidPayer();

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
   * @param _subject The subject that is passed to the space contract
   * @param _data The arbitrary data for space contract execution
   * @param _signature The signature for account verification
   */
  function enter(
    bytes16 _fromSpaceId,
    bytes16 _toSpaceId,
    bytes32 _action,
    bytes32 _subject,
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
   * @notice Archives a space ID in the registry, marking it as archived
   */
  function archiveSpaceId() external;

  /**
   * @notice Recovers an archived space ID, removing it's archived status
   * @dev Can only be called by the address that was associated with the archived space ID
   */
  function recoverSpaceId() external;

  /**
   * @notice Clears a space ID from the registry, completely unregistering it
   * @dev Removes all mappings for the space, allowing the address to accept migrations
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
   * @notice Allows the owner to override or set the bi-directional mapping for a space ID and account
   * @dev Clears any existing mappings for the given _spaceId and _account, then sets the new mapping. Emits SPACE_ID_OVERRIDDEN.
   *      Reverts with OverrideZero if _account or _spaceId is zero. Reverts with InvalidAccount if _account is this registry.
   * @dev WARNING: For an active DAOSpace proxy, only bind _account to the dao's configured space id (e.g. transplant id) or
   *      mappings consistent with that deployment. Arbitrary rebinding desynchronizes on-chain roles from the registry and
   *      can brick governance the same way.
   * @param _account The account to bind to _spaceId
   * @param _spaceId The space ID to bind to _account
   */
  function overrideSpaceId(address _account, bytes16 _spaceId) external;

  /**
   * @notice Allows the owner to emit arbitrary Action events for indexer consistency
   * @param _fromSpaceIds The space ID for the fromSpaceId of each emitted Action
   * @param _toSpaceIds The space ID for the toSpaceId of each emitted Action
   * @param _actions Action identifiers
   * @param _subjects Subject for each Action event
   * @param _datas Data for each Action event
   * @dev All of the input arrays must have the same length
   */
  function overrideAction(
    bytes16[] calldata _fromSpaceIds,
    bytes16[] calldata _toSpaceIds,
    bytes32[] calldata _actions,
    bytes32[] calldata _subjects,
    bytes[] calldata _datas
  ) external;

  /**
   * @notice Allows the owner to add or remove permissionless actions
   * @param _action The action identifier
   * @param _set The boolean of whether or not the action is permissionless (true if it is, no otherwise)
   * @dev Permissionless actions are those where, even if the caller is not the toSpace, fetch and write do not occur
   */
  function setPermissionlessAction(bytes32 _action, bool _set) external;

  /**
   * @notice Sets the Arbitrum PaymentManager proxy used for cross-chain payer updates
   * @dev Emits `Action` with `GOVERNANCE.PAYMENT_MANAGER_SET`.
   * @param _paymentManager PaymentManager proxy address
   */
  function setPaymentManager(address _paymentManager) external;

  /**
   * @notice Queues an L2 PaymentManager.setPayer call for the caller space's incentives target
   * @dev Callable only by an active registered space (msg.sender). Emits `Action` with `GOVERNANCE.L2_INCENTIVES_PAYER_SET`.
   *      L2 incentives (PaymentManager, Rewarder, StakingManager) key state by a canonical `bytes32` target id. For spaces,
   *      geo-incentives (`StakingRegistry.getTargetId`) defines that id as `bytes32(bytes16 spaceId)`. L3 must use the same
   *      encoding in cross-chain calldata and in the Action `subject` so `setPayer`, merkle rewards, allocations, and claims
   *      align.
   * @param _payer Address authorized to create payments on L2 for this space's target
   */
  function setL2IncentivesPayer(address _payer) external;

  /**
   * @notice Returns the configured Arbitrum PaymentManager proxy
   * @return _paymentManager PaymentManager proxy address
   */
  function paymentManager() external view returns (address _paymentManager);

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
   * @notice Checks if a space ID is registered (has an address mapping)
   * @param _spaceId The ID of the space to check
   * @return _isRegistered True if the space ID has an address mapping, false otherwise
   */
  function registeredSpaceIds(bytes16 _spaceId) external view returns (bool _isRegistered);

  /**
   * @notice Checks if an address is registered (has a space ID mapping)
   * @param _account The address of the space to check
   * @return _isRegistered True if the address has a space ID mapping, false otherwise
   */
  function registeredSpaceAddresses(address _account) external view returns (bool _isRegistered);

  /**
   * @notice Maps each space ID to whether it has been archived
   * @param _spaceId The ID of the space to check
   * @return _isArchived True if the space ID is archived, false otherwise
   */
  function archivedSpaceIds(bytes16 _spaceId) external view returns (bool _isArchived);

  /**
   * @notice Checks if a space ID is active (registered and not archived)
   * @param _spaceId The ID of the space to check
   * @return _isActive True if the space ID is registered and not archived, false otherwise
   */
  function activeSpaceIds(bytes16 _spaceId) external view returns (bool _isActive);

  /**
   * @notice Generates a UUID v4 compliant space ID for a given address and nonce
   * @param _account The address to generate a space ID for
   * @param _nonce The nonce to generate a space ID for
   * @return _spaceId The UUID v4 compliant bytes16 space ID
   */
  function generateSpaceId(address _account, uint256 _nonce) external view returns (bytes16 _spaceId);
}
