// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IOutbox} from 'interfaces/L2/IOutbox.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title IPaymentManager
 * @notice Interface for managing GEO token payments to Spaces with a configurable delay and council oversight
 */
interface IPaymentManager is ISemver {
  /**
   * @notice Delayed transfer request (mirrors `StakingManager.UnstakeRequest` naming)
   * @param targetId Merkle target identifier for the Space (same key as Rewarder rewards)
   * @param recipient Address that will receive the payment
   * @param amount Amount of GEO tokens in the request
   * @param unlockTime Earliest timestamp at which the request may be executed
   * @dev `unlockTime` is fixed at creation so a later configuration change cannot shorten or extend an in-flight request.
   *      Completed or slashed requests are deleted from storage; history is available via events.
   */
  struct PaymentRequest {
    bytes32 targetId;
    address recipient;
    uint256 amount;
    uint256 unlockTime;
  }

  /**
   * @notice Parameters required for initializing the PaymentManager contract
   * @param arbitrumGeoToken Address of the GEO ERC-20 on Arbitrum (bridged from Ethereum L1)
   * @param outbox Address of the Outbox contract for cross-chain message verification
   * @param rewarder Address of the Rewarder contract that can credit per-target GEO balances
   * @param escrow Address of the Escrow contract that receives GEO when a payment request is slashed
   * @param spaceRegistry Address of the L3 SpaceRegistry contract acting as a verification filter for cross-chain messages
   * @param council Address of the council (owner) that can slash requests, reclaim rewards, and set the delay
   * @param paymentRequestDelay Duration in seconds before a new payment request may be executed
   */
  struct PaymentManagerInitializationParams {
    address arbitrumGeoToken;
    address outbox;
    address rewarder;
    address escrow;
    address spaceRegistry;
    address council;
    uint256 paymentRequestDelay;
  }

  /**
   * @notice ERC-7201 namespaced storage for PaymentManager.
   * @param arbitrumGeoToken The bridged GEO ERC-20 on Arbitrum
   * @param outbox The Outbox contract for L3 sender verification
   * @param rewarder The Rewarder contract address authorized to credit target balances
   * @param escrow The Escrow contract address that receives GEO when a payment request is slashed or rewards are reclaimed
   * @param spaceRegistry The L3 SpaceRegistry contract address authorized to set payers via cross-chain messages
   * @param paymentRequestDelay Seconds a payment request must wait before execution
   * @param paymentNonce Monotonic nonce assigning payment request ids
   * @param totalTargetBalance GEO balance accrued per Merkle target id
   * @param payers Authorized payer address per Merkle target id
   * @param payments Payment request records by payment id
   * @custom:storage-location erc7201:geo.storage.PaymentManager
   */
  struct PaymentManagerStorage {
    IERC20 arbitrumGeoToken;
    IOutbox outbox;
    address rewarder;
    address escrow;
    address spaceRegistry;
    uint256 paymentRequestDelay;
    uint256 paymentNonce;
    mapping(bytes32 _targetId => uint256 _balance) totalTargetBalance;
    mapping(bytes32 _targetId => address _payer) payers;
    mapping(uint256 _paymentId => PaymentRequest _payment) payments;
  }

  /**
   * @notice Emitted when the payment request delay is updated
   * @param _paymentRequestDelay The new delay in seconds
   */
  event PaymentRequestDelaySet(uint256 _paymentRequestDelay);

  /**
   * @notice Emitted when a payer is set for a target via cross-chain message
   * @param targetId Merkle target identifier
   * @param newPayer Authorized payer address for the target
   */
  event PayerSet(bytes32 indexed targetId, address indexed newPayer);

  /**
   * @notice Emitted when GEO rewards are received and assigned to a target balance
   * @param targetId Merkle target identifier receiving the rewards
   * @param amount Amount of GEO tokens received
   */
  event RewardReceived(bytes32 indexed targetId, uint256 amount);

  /**
   * @notice Emitted when a new payment request is created
   * @param paymentId Unique identifier for the payment request
   * @param targetId Merkle target identifier for the originating Space
   * @param recipient Address set to receive the payment
   * @param amount Amount of GEO tokens locked
   * @param unlockTime Timestamp from which the request may be executed
   */
  event PaymentCreated(
    uint256 indexed paymentId, bytes32 indexed targetId, address indexed recipient, uint256 amount, uint256 unlockTime
  );

  /**
   * @notice Emitted when a payment request is slashed by the council
   * @param paymentId Unique identifier for the payment request
   */
  event PaymentSlashed(uint256 indexed paymentId);

  /**
   * @notice Emitted when the council reclaims GEO rewards from a target balance back to escrow
   * @param targetId Merkle target identifier whose balance was reduced
   * @param amount Amount of GEO tokens transferred to escrow
   */
  event RewardsReclaimed(bytes32 indexed targetId, uint256 amount);

  /**
   * @notice Emitted when a payment request is successfully executed
   * @param paymentId Unique identifier for the payment request
   * @param recipient Address that received the payment
   * @param amount Amount of GEO tokens transferred
   */
  event PaymentExecuted(uint256 indexed paymentId, address indexed recipient, uint256 amount);

  /// @notice Thrown when a cross-chain message origin is invalid
  error InvalidL3Sender();

  /// @notice Thrown when a function restricted to the Rewarder is called by another address
  error OnlyRewarder();

  /// @notice Thrown when the caller is not the authorized payer for the given target
  error UnauthorizedPayer();

  /// @notice Thrown when a payer attempts to create a payment but lacks sufficient target balance
  error InsufficientTargetBalance();

  /// @notice Thrown when the provided payment ID does not exist
  error InvalidPayment();

  /// @notice Thrown when attempting to execute a payment before its unlock time
  error PaymentRequestLocked();

  /// @notice Thrown when the provided address is invalid
  error InvalidAddress();

  /// @notice Thrown when `_targetId == bytes32(0)`; zero is reserved as the unset sentinel and must not be configured
  error InvalidTargetId();

  /// @notice Thrown when a payment amount is zero
  error ZeroAmount();

  /**
   * @notice Initializes the PaymentManager contract
   * @dev Can only be called once during proxy deployment.
   * @param _initParams The initialization parameters
   * @custom:reverts InvalidAddress when any dependency address in `_initParams` is zero
   */
  function initialize(PaymentManagerInitializationParams calldata _initParams) external;

  /**
   * @notice Sets the delay applied to new payment requests
   * @dev Callable only by the owner (council).
   * @param _paymentRequestDelay New delay in seconds
   */
  function setPaymentRequestDelay(uint256 _paymentRequestDelay) external;

  /**
   * @notice Sets the payer for a Merkle target id via cross-chain message
   * @dev Callable only via the bridge path that surfaces `spaceRegistry` as `outbox.l2ToL1Sender()`.
   * @param _targetId Merkle target identifier (must match the id used in Rewarder rewards)
   * @param _payer Address of the payer
   * @custom:reverts InvalidTargetId when `_targetId == bytes32(0)`;
   *   InvalidL3Sender when `outbox.l2ToL1Sender()` is not `spaceRegistry`
   */
  function setPayer(bytes32 _targetId, address _payer) external;

  /**
   * @notice Processes GEO rewards pulled from escrow for a given target
   * @dev State is keyed by `_targetId` exactly as supplied by the Rewarder.
   * @param _targetId Merkle target identifier
   * @param _amount Amount of GEO tokens to assign to the target balance
   * @custom:reverts OnlyRewarder when `msg.sender` is not `rewarder`;
   *   InvalidTargetId when `_targetId == bytes32(0)`
   */
  function processRewards(bytes32 _targetId, uint256 _amount) external;

  /**
   * @notice Creates a new payment request from a target to a recipient
   * @param _targetId Merkle target identifier for the Space initiating the payment
   * @param _recipient Address that will receive the GEO tokens
   * @param _amount Amount of GEO tokens to transfer (must be non-zero)
   * @return _paymentId Unique identifier for the payment request
   * @custom:reverts UnauthorizedPayer when caller is not `payers(_targetId)`;
   *   InvalidTargetId when `_targetId == bytes32(0)`;
   *   InvalidAddress when `_recipient == address(0)`;
   *   ZeroAmount when `_amount == 0`;
   *   InsufficientTargetBalance when `totalTargetBalance(_targetId) < _amount`
   */
  function createPayment(bytes32 _targetId, address _recipient, uint256 _amount) external returns (uint256 _paymentId);

  /**
   * @notice Cancels a pending payment request and returns its GEO to escrow before execution
   * @dev Callable only by the owner (council). Request must exist and not have been completed or slashed
   * @param _paymentId ID of the payment request to slash
   * @custom:reverts InvalidPayment when `_paymentId` does not exist
   */
  function slashPayment(uint256 _paymentId) external;

  /**
   * @notice Reclaims GEO rewards from a target's available balance and returns them to escrow
   * @dev Callable only by the owner (council). Only reduces `totalTargetBalance`; rewards locked in pending payment
   * requests must be reclaimed via `slashPayment`
   * @param _targetId Merkle target identifier whose rewards to reclaim
   * @param _amount Amount of GEO tokens to reclaim (must be non-zero and not exceed the target balance)
   * @custom:reverts InvalidTargetId when `_targetId == bytes32(0)`;
   *   ZeroAmount when `_amount == 0`;
   *   InsufficientTargetBalance when `totalTargetBalance(_targetId) < _amount`
   */
  function reclaimRewards(bytes32 _targetId, uint256 _amount) external;

  /**
   * @notice Executes a payment request after the delay has elapsed
   * @dev Callable by anyone. Request must exist and not have been completed or slashed
   * @param _paymentId ID of the payment request to execute
   * @custom:reverts InvalidPayment when `_paymentId` does not exist;
   *   PaymentRequestLocked when `block.timestamp < unlockTime`
   */
  function executePayment(uint256 _paymentId) external;

  /**
   * @notice Returns the bridged GEO ERC-20 on Arbitrum
   * @return _arbitrumGeoToken Address of the Arbitrum GEO token
   */
  function arbitrumGeoToken() external view returns (IERC20 _arbitrumGeoToken);

  /**
   * @notice Returns the Outbox contract address for cross-chain message verification
   * @return _outbox Address of the Outbox contract
   */
  function outbox() external view returns (IOutbox _outbox);

  /**
   * @notice Returns the Rewarder address
   * @return _rewarder Address of the Rewarder contract
   */
  function rewarder() external view returns (address _rewarder);

  /**
   * @notice Returns the Escrow address that receives GEO when a payment request is slashed or rewards are reclaimed
   * @return _escrow Address of the Escrow contract
   */
  function escrow() external view returns (address _escrow);

  /**
   * @notice Returns the SpaceRegistry address authorized for cross-chain payer updates
   * @return _spaceRegistry Address of the L3 SpaceRegistry contract
   */
  function spaceRegistry() external view returns (address _spaceRegistry);

  /**
   * @notice Returns the global payment request delay in seconds
   * @return _paymentRequestDelay Current delay duration in seconds
   */
  function paymentRequestDelay() external view returns (uint256 _paymentRequestDelay);

  /**
   * @notice Returns the current payment nonce used to assign payment request ids
   * @return _paymentNonce Next id to assign (post-increment semantics match `createPayment`)
   */
  function paymentNonce() external view returns (uint256 _paymentNonce);

  /**
   * @notice Returns the available GEO token balance accrued for a Merkle target id
   * @param _targetId Merkle target identifier
   * @return _balance Amount of GEO tokens held for that target
   */
  function totalTargetBalance(bytes32 _targetId) external view returns (uint256 _balance);

  /**
   * @notice Returns the payer address for a Merkle target id
   * @param _targetId Merkle target identifier
   * @return _payer Address of the payer for that target
   */
  function payers(bytes32 _targetId) external view returns (address _payer);

  /**
   * @notice Returns full details of a payment request
   * @param _paymentId Unique identifier of the payment request
   * @return _payment The stored request struct
   */
  function payments(uint256 _paymentId) external view returns (PaymentRequest memory _payment);
}
