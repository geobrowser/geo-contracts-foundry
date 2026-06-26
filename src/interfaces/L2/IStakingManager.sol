// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IStakedGEOToken} from 'interfaces/L2/IStakedGEOToken.sol';
import {IStakingRegistry} from 'interfaces/L2/IStakingRegistry.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title IStakingManager
 * @notice Custodies staked GEO and user allocations, enforcing council-approved targets via `IStakingRegistry`
 */
interface IStakingManager is ISemver {
  /**
   * @notice Struct for pending unstake requests
   * @param user The address of the user requesting the unstake
   * @param amount The amount of tokens to unstake
   * @param unlockTime The time at which the unstake can be executed
   */
  struct UnstakeRequest {
    address user;
    uint256 amount;
    uint256 unlockTime;
  }

  /**
   * @notice Struct used to initialize the StakingManager contract
   * @dev This struct is passed to the initializer
   * @param arbitrumGeoToken Address of the GEO ERC-20 on Arbitrum (bridged from Ethereum L1)
   * @param council The address of the GEO multisig council
   * @param stakingRegistry The address of the `StakingRegistry` contract listing targets users may allocate to
   * @param stakedGEOToken The soulbound voting token minted and burned on stake and unstake
   * @param minAmount Minimum (non-zero) for stake, allocate, reallocate, and for partial `requestUnstake` / `deallocate` unless fully exiting disposable stake or a target.
   * @param unstakeRequestDelay The delay between requesting an unstake and being able to execute it (must not exceed `MAX_UNSTAKE_REQUEST_DELAY`)
   */
  struct StakingManagerInitializationParams {
    address arbitrumGeoToken;
    address council;
    address stakingRegistry;
    address stakedGEOToken;
    uint256 minAmount;
    uint256 unstakeRequestDelay;
  }

  /**
   * @notice ERC-7201 namespaced storage for StakingManager.
   * @param arbitrumGeoToken The bridged GEO ERC-20 on Arbitrum
   * @param stakingRegistry Registry of allocation targets the council may activate for staking allocations
   * @param stakedGEOToken Soulbound voting token minted and burned on stake and unstake
   * @param minAmount Minimum (non-zero) for stake, allocate, reallocate, and for partial `requestUnstake` / `deallocate` unless fully exiting disposable stake or a target.
   * @param unstakeRequestDelay The delay between requesting an unstake and being able to execute it (capped by `MAX_UNSTAKE_REQUEST_DELAY`)
   * @param totalStaked The total amount of tokens currently staked (including tokens pending unstake)
   * @param totalPendingUnstake The total amount of tokens requested to be unstaked but not yet withdrawn
   * @param totalAllocated The total amount of tokens allocated to targets
   * @param unstakeRequestNonce The next unstake request identifier to assign
   * @param totalUserStake Mapping of user addresses to their total staked amount (including tokens pending unstake)
   * @param unstakeRequests Mapping of unstake request IDs to their details
   * @param totalUserAllocation Mapping of user addresses to their total allocated amount
   * @param totalTargetAllocation Mapping of target IDs to the total allocated amount for that target
   * @param allocations Mapping of user addresses to target IDs to the allocated amount for that user and target
   * @param totalUserPendingUnstake Mapping of user addresses to their amount of stake currently in the unstake queue
   * @custom:storage-location erc7201:geo.storage.StakingManager
   */
  struct StakingManagerStorage {
    IERC20 arbitrumGeoToken;
    IStakingRegistry stakingRegistry;
    IStakedGEOToken stakedGEOToken;
    uint256 minAmount;
    uint256 unstakeRequestDelay;
    uint256 totalStaked;
    uint256 totalPendingUnstake;
    uint256 totalAllocated;
    uint256 unstakeRequestNonce;
    mapping(address _user => uint256 _amount) totalUserStake;
    mapping(uint256 _unstakeId => UnstakeRequest _unstakeRequest) unstakeRequests;
    mapping(address _user => uint256 _amount) totalUserAllocation;
    mapping(bytes32 _targetId => uint256 _amount) totalTargetAllocation;
    mapping(address _user => mapping(bytes32 _targetId => uint256 _amount)) allocations;
    mapping(address _user => uint256 _amount) totalUserPendingUnstake;
  }

  /**
   * @notice Emitted when the minimum interaction amount is set
   * @param _minAmount The new minimum amount
   */
  event MinAmountSet(uint256 _minAmount);

  /**
   * @notice Emitted when the unstake request delay is set
   * @param _unstakeRequestDelay The new unstake request delay
   */
  event UnstakeRequestDelaySet(uint256 _unstakeRequestDelay);

  /**
   * @notice Emitted when GEO tokens are staked
   * @param _staker The account `arbitrumGeoToken` was pulled from
   * @param _recipient The account credited with staked GEO
   * @param _amount The amount of tokens staked
   */
  event Staked(address indexed _staker, address indexed _recipient, uint256 _amount);

  /**
   * @notice Emitted when a user requests to unstake tokens
   * @param _unstakeId The ID of the unstake request
   * @param _user The address of the user who requested the unstake
   * @param _amount The amount of tokens requested to be unstaked
   * @param _unlockTime The time at which the unstake can be executed
   */
  event UnstakeRequested(uint256 indexed _unstakeId, address indexed _user, uint256 _amount, uint256 _unlockTime);

  /**
   * @notice Emitted when a user unstakes tokens
   * @param _unstakeId The ID of the unstake request
   */
  event Unstaked(uint256 indexed _unstakeId);

  /**
   * @notice Emitted when a user allocates tokens to a target
   * @param _user The address of the user who allocated tokens
   * @param _targetId The ID of the target to which tokens were allocated
   * @param _amount The amount of tokens allocated
   */
  event Allocated(address indexed _user, bytes32 indexed _targetId, uint256 _amount);

  /**
   * @notice Emitted when a user deallocates tokens from a target
   * @param _user The address of the user who deallocated tokens
   * @param _targetId The ID of the target from which tokens were deallocated
   * @param _amount The amount of tokens deallocated
   */
  event Deallocated(address indexed _user, bytes32 indexed _targetId, uint256 _amount);

  /**
   * @notice Emitted when a user reallocates tokens from one target to another
   * @param _user The address of the user who reallocated tokens
   * @param _fromTargetId The ID of the target from which tokens were reallocated
   * @param _toTargetId The ID of the target to which tokens were reallocated
   * @param _amount The amount of tokens reallocated
   */
  event Reallocated(address indexed _user, bytes32 indexed _fromTargetId, bytes32 indexed _toTargetId, uint256 _amount);

  /// @notice Thrown when an amount is below the configured minimum (except for a full disposable unstake request or a full target deallocation)
  error AmountBelowMinimum();

  /// @notice Thrown when `deallocate` or `reallocate` would leave a non-zero allocation on a target below `minAmount`
  error AllocationRemainderBelowMinimum();

  /// @notice Thrown when `requestUnstake` would leave a non-zero disposable stake below `minAmount` (full disposable exit is allowed)
  error DisposableStakeRemainderBelowMinimum();

  /// @notice Thrown when a zero GEO amount is invalid (e.g. `requestUnstake`, `deallocate`, or configuring `minAmount` to zero)
  error ZeroAmount();

  /// @notice Thrown when a user tries to unstake or allocate more than their disposable staked amount
  error InsufficientDisposableStake();

  /// @notice Thrown when no unstake request exists for the given ID
  error UnstakeRequestNotFound();

  /// @notice Thrown when the caller is not the owner of the unstake request
  error UnstakeRequestUnauthorized();

  /// @notice Thrown when a user tries to unstake before the unlock time
  error UnstakeRequestLocked();

  /// @notice Thrown when a user tries to deallocate or reallocate more than their allocated amount
  error InsufficientAllocation();

  /// @notice Thrown when an invalid address is provided
  error InvalidAddress();

  /// @notice Thrown when reallocate is called with identical source and destination targets
  error SameReallocationTargets();

  /// @notice Thrown when allocating or reallocating to a target that is inactive in `StakingRegistry`
  error InactiveAllocationTarget();

  /// @notice Thrown when configuring an unstake delay above `MAX_UNSTAKE_REQUEST_DELAY`
  error UnstakeRequestDelayExceedsMaximum();

  /**
   * @notice Initializes the StakingManager contract
   * @param _initParams The initialization parameters
   * @custom:reverts InvalidAddress when `arbitrumGeoToken`, `stakingRegistry`, or `stakedGEOToken` is zero;
   *   ZeroAmount when `minAmount` is zero;
   *   UnstakeRequestDelayExceedsMaximum when `unstakeRequestDelay` exceeds `MAX_UNSTAKE_REQUEST_DELAY`
   */
  function initialize(StakingManagerInitializationParams calldata _initParams) external;

  /**
   * @notice Sets the minimum interaction amount
   * @dev Callable only by the owner (council).
   * @param _minAmount The configured minimum amount (must be non-zero)
   * @custom:reverts ZeroAmount when `_minAmount == 0`
   */
  function setMinAmount(uint256 _minAmount) external;

  /**
   * @notice Sets the delay for unstake requests
   * @dev Callable only by the owner (council).
   * @param _unstakeRequestDelay The delay between requesting an unstake and being able to execute it (must not exceed `MAX_UNSTAKE_REQUEST_DELAY`)
   * @custom:reverts UnstakeRequestDelayExceedsMaximum when `_unstakeRequestDelay` exceeds `MAX_UNSTAKE_REQUEST_DELAY`
   */
  function setUnstakeRequestDelay(uint256 _unstakeRequestDelay) external;

  /**
   * @notice Stakes a specified amount of GEO tokens
   * @param _amount The amount of GEO tokens to stake
   * @custom:reverts AmountBelowMinimum when `_amount < minAmount`
   */
  function stake(uint256 _amount) external;

  /**
   * @notice Stakes GEO on behalf of `_recipient`, pulling tokens from the caller
   * @param _recipient The account to credit with staked GEO
   * @param _amount The amount of GEO tokens to stake
   * @custom:reverts InvalidAddress when `_recipient == address(0)`;
   *   AmountBelowMinimum when `_amount < minAmount`
   */
  function stakeFor(address _recipient, uint256 _amount) external;

  /**
   * @notice Requests to unstake a specified amount of tokens
   * @param _amount The amount of GEO tokens to move from disposable stake into a timed unstake request.
   * @return _unstakeId The ID of the unstake request
   * @dev The `_amount` must be non-zero. Unless `_amount` equals the caller's entire disposable stake, `_amount` must be at least `minAmount`. After this call, the caller's remaining disposable stake is either zero or at least `minAmount`.
   * @custom:reverts ZeroAmount when `_amount == 0`;
   *   InsufficientDisposableStake when `_amount` exceeds disposable stake;
   *   AmountBelowMinimum when partial unstake is below `minAmount`;
   *   DisposableStakeRemainderBelowMinimum when remaining disposable stake would be below `minAmount`
   */
  function requestUnstake(uint256 _amount) external returns (uint256 _unstakeId);

  /**
   * @notice Unstakes tokens for a given unstake request ID
   * @param _unstakeId The ID of the unstake request to execute
   * @custom:reverts UnstakeRequestNotFound when `_unstakeId` does not exist;
   *   UnstakeRequestUnauthorized when caller is not the request owner;
   *   UnstakeRequestLocked when `block.timestamp < unlockTime`
   */
  function unstake(uint256 _unstakeId) external;

  /**
   * @notice Allocates a specified amount of tokens to a target
   * @param _targetId The ID of the target to allocate to
   * @param _amount The amount of tokens to allocate (at least `minAmount`)
   * @custom:reverts InsufficientDisposableStake when `_amount` exceeds disposable stake;
   *   AmountBelowMinimum when `_amount < minAmount`;
   *   InactiveAllocationTarget when `_targetId` is inactive in `StakingRegistry`
   */
  function allocate(bytes32 _targetId, uint256 _amount) external;

  /**
   * @notice Deallocates a specified amount of tokens from a target
   * @param _targetId The ID of the target to deallocate from
   * @param _amount The amount of GEO tokens to remove from the caller's allocation on `_targetId`.
   * @dev The `_amount` must be non-zero. Unless `_amount` equals the caller's entire allocation on `_targetId`, `_amount` must be at least `minAmount`. After this call, the allocation remaining on `_targetId` for the caller is either zero or at least `minAmount`.
   * @custom:reverts ZeroAmount when `_amount == 0`;
   *   InsufficientAllocation when `_amount` exceeds the caller's allocation;
   *   AmountBelowMinimum when partial deallocation is below `minAmount`;
   *   AllocationRemainderBelowMinimum when remaining allocation would be below `minAmount`
   */
  function deallocate(bytes32 _targetId, uint256 _amount) external;

  /**
   * @notice Reallocates a specified amount of tokens from one target to another
   * @param _fromTargetId The ID of the target to reallocate from
   * @param _toTargetId The ID of the target to reallocate to
   * @param _amount The amount of GEO tokens to move from `_fromTargetId` to `_toTargetId`. Must be at least `minAmount`. After this call, the allocation remaining on `_fromTargetId` for the caller is either zero or at least `minAmount`.
   * @custom:reverts SameReallocationTargets when `_fromTargetId == _toTargetId`;
   *   InsufficientAllocation when `_amount` exceeds source allocation;
   *   AmountBelowMinimum when `_amount < minAmount`;
   *   AllocationRemainderBelowMinimum when remaining source allocation would be below `minAmount`;
   *   InactiveAllocationTarget when `_toTargetId` is inactive in `StakingRegistry`
   */
  function reallocate(bytes32 _fromTargetId, bytes32 _toTargetId, uint256 _amount) external;

  /**
   * @notice Returns the bridged GEO ERC-20 on Arbitrum
   * @return _arbitrumGeoToken The Arbitrum GEO ERC-20
   */
  function arbitrumGeoToken() external view returns (IERC20 _arbitrumGeoToken);

  /**
   * @notice Returns the staking registry used to validate allocation targets
   * @return _stakingRegistry The registry contract
   */
  function stakingRegistry() external view returns (IStakingRegistry _stakingRegistry);

  /**
   * @notice Returns the soulbound voting token minted and burned on stake and unstake
   * @return _stakedGEOToken The `StakedGEOToken` contract
   */
  function stakedGEOToken() external view returns (IStakedGEOToken _stakedGEOToken);

  /**
   * @notice Returns the configured minimum interaction amount
   * @return _minAmount The minimum amount
   */
  function minAmount() external view returns (uint256 _minAmount);

  /**
   * @notice Returns the delay between requesting an unstake and being able to execute it
   * @return _unstakeRequestDelay The unstake request delay
   */
  function unstakeRequestDelay() external view returns (uint256 _unstakeRequestDelay);

  /**
   * @notice Maximum unstake request delay the owner may set (one month, sanity bound)
   * @return _maxUnstakeRequestDelay The cap in seconds
   */
  function MAX_UNSTAKE_REQUEST_DELAY() external view returns (uint256 _maxUnstakeRequestDelay);

  /**
   * @notice Returns the total amount of tokens currently staked (including tokens pending unstake)
   * @return _totalStaked The total amount of tokens staked
   */
  function totalStaked() external view returns (uint256 _totalStaked);

  /**
   * @notice Returns the total amount of tokens requested to be unstaked but not yet withdrawn
   * @return _totalPendingUnstake The total amount pending unstake
   */
  function totalPendingUnstake() external view returns (uint256 _totalPendingUnstake);

  /**
   * @notice Returns the total amount of tokens allocated to targets
   * @return _totalAllocated The total amount allocated
   */
  function totalAllocated() external view returns (uint256 _totalAllocated);

  /**
   * @notice Returns the next unstake request identifier to be assigned
   * @return _unstakeRequestNonce The unstake request nonce
   */
  function unstakeRequestNonce() external view returns (uint256 _unstakeRequestNonce);

  /**
   * @notice Returns the total amount of tokens staked by a user (including tokens pending unstake)
   * @param _user The address of the user
   * @return _amount The total amount of tokens staked by the user
   */
  function totalUserStake(address _user) external view returns (uint256 _amount);

  /**
   * @notice Returns the amount of a user's stake that is currently in the unstake queue
   * @param _user The address of the user
   * @return _amount The amount pending unstake for the user
   */
  function totalUserPendingUnstake(address _user) external view returns (uint256 _amount);

  /**
   * @notice Returns the unstake request for a given unstake ID
   * @param _unstakeId The ID of the unstake request
   * @return _unstakeRequest The unstake request
   */
  function unstakeRequests(uint256 _unstakeId) external view returns (UnstakeRequest memory _unstakeRequest);

  /**
   * @notice Returns the total amount of tokens allocated by a user
   * @param _user The address of the user
   * @return _amount The total amount of tokens allocated by the user
   */
  function totalUserAllocation(address _user) external view returns (uint256 _amount);

  /**
   * @notice Returns stake available to allocate or request to unstake (`totalUserStake - totalUserPendingUnstake - totalUserAllocation`)
   * @param _user The address of the user
   * @return _disposableStake The user's disposable stake
   */
  function totalUserDisposableStake(address _user) external view returns (uint256 _disposableStake);

  /**
   * @notice Returns the total amount of tokens allocated to a target
   * @param _targetId The ID of the target
   * @return _amount The total amount of tokens allocated to the target
   */
  function totalTargetAllocation(bytes32 _targetId) external view returns (uint256 _amount);

  /**
   * @notice Returns the amount of tokens allocated by a user to a target
   * @param _user The address of the user
   * @param _targetId The ID of the target
   * @return _amount The amount of tokens allocated by the user to the target
   */
  function allocations(address _user, bytes32 _targetId) external view returns (uint256 _amount);
}
