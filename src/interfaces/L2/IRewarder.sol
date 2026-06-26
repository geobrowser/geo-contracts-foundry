// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {IEscrow} from 'interfaces/L2/IEscrow.sol';
import {IPaymentManager} from 'interfaces/L2/IPaymentManager.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title IRewarder
 * @notice Interface for the GEO incentives Rewarder contract
 * @dev Distributes GEO from escrow using Merkle proofs per epoch for users and targets
 */
interface IRewarder is ISemver {
  /**
   * @notice Struct used to initialize the Rewarder contract
   * @dev This struct is passed to the initializer
   * @param escrow The escrow holding GEO incentives supply (token is `escrow.arbitrumGeoToken()`)
   * @param paymentManager The PaymentManager address
   * @param council The Council multisig address
   */
  struct RewarderInitializationParams {
    address escrow;
    address paymentManager;
    address council;
  }

  /**
   * @notice ERC-7201 namespaced storage for Rewarder.
   * @param escrow Escrow holding GEO incentives
   * @param paymentManager The PaymentManager contract
   * @param merkleRoot Mapping of epoch to Merkle root of rewards distribution
   * @param totalClaimableRewards Mapping of epoch to total claimable rewards for that epoch
   * @param userClaimed Mapping to track if a user has claimed rewards for a target for an epoch
   * @param targetClaimed Mapping to track if a target has claimed rewards for an epoch
   * @param merkleRootRevoked Mapping to track whether an epoch's published Merkle root has been revoked
   * @custom:storage-location erc7201:geo.storage.Rewarder
   */
  struct RewarderStorage {
    IEscrow escrow;
    IPaymentManager paymentManager;
    mapping(uint256 _epoch => bytes32 _root) merkleRoot;
    mapping(uint256 _epoch => uint256 _amount) totalClaimableRewards;
    mapping(address _user => mapping(bytes32 _targetId => mapping(uint256 _epoch => bool _claimed))) userClaimed;
    mapping(bytes32 _targetId => mapping(uint256 _epoch => bool _claimed)) targetClaimed;
    mapping(uint256 _epoch => bool _revoked) merkleRootRevoked;
  }

  /**
   * @notice Emitted when a Merkle root is published for an epoch
   * @param _epoch The epoch for which the Merkle root is published
   * @param _root The Merkle root for the specified epoch
   * @param _totalClaimableRewards The total claimable rewards for the specified epoch
   */
  event MerkleRootPublished(uint256 indexed _epoch, bytes32 _root, uint256 _totalClaimableRewards);

  /**
   * @notice Emitted when a user claims rewards for one epoch entry
   * @param _user The address of the user claiming rewards
   * @param _targetId The target ID for which rewards are claimed
   * @param _epoch The epoch claimed
   * @param _amount The amount claimed for the epoch
   */
  event UserRewardsClaimed(address indexed _user, bytes32 indexed _targetId, uint256 indexed _epoch, uint256 _amount);

  /**
   * @notice Emitted when target rewards are claimed for one epoch entry
   * @param _targetId The target ID for which rewards are claimed
   * @param _epoch The epoch claimed
   * @param _amount The amount claimed for the epoch
   */
  event TargetRewardsClaimed(bytes32 indexed _targetId, uint256 indexed _epoch, uint256 _amount);

  /**
   * @notice Emitted when a published Merkle root is permanently revoked for an epoch
   * @dev Revocation is final: the epoch cannot be republished and remaining claimable rewards are zeroed
   * @param _epoch The epoch whose Merkle root was revoked
   */
  event MerkleRootRevoked(uint256 indexed _epoch);

  /// @notice Thrown when a Merkle root for an epoch has already been published
  error MerkleRootAlreadyPublished();

  /// @notice Thrown when revoking an epoch that has no published Merkle root
  error MerkleRootNotPublished();

  /// @notice Thrown when revoking an epoch whose Merkle root is already revoked
  error MerkleRootAlreadyRevoked();

  /// @notice Thrown when claiming rewards for an epoch whose Merkle root has been revoked
  error MerkleRootIsRevoked();

  /// @notice Thrown when a user tries to claim a reward that has already been claimed
  error RewardAlreadyClaimed();

  /// @notice Thrown when a user provides an invalid Merkle proof for claiming rewards
  error InvalidProof();

  /// @notice Thrown when the total claimable rewards for an epoch are exceeded
  error TotalClaimableRewardsExceeded();

  /// @notice Thrown when published total claimable rewards exceeds the configured cap
  error TotalClaimableRewardsCapExceeded();

  /// @notice Thrown when an invalid address is provided
  error InvalidAddress();

  /// @notice Thrown when `_targetId == bytes32(0)`; zero is reserved as the unset sentinel and must not be claimed
  error InvalidTargetId();

  /// @notice Thrown when input array lengths do not match
  error InvalidArrayLength();

  /// @notice Thrown when a batch claim lists more epochs than allowed per transaction
  error TooManyEpochsPerClaim();

  /// @notice Thrown when an invalid Merkle root is provided for publication
  error InvalidMerkleRoot();

  /// @notice Thrown when total claimable rewards is zero for publication
  error InvalidTotalClaimableRewards();

  /**
   * @notice Initializes the Rewarder contract
   * @param _initParams The initialization parameters
   * @custom:reverts InvalidAddress when `escrow` or `paymentManager` is zero
   */
  function initialize(RewarderInitializationParams calldata _initParams) external;

  /**
   * @notice Publishes the Merkle root for an epoch's rewards distribution
   * @dev Callable only by the owner (council).
   * @param _epoch The epoch for which to publish the Merkle root
   * @param _root The Merkle root representing the rewards distribution for the epoch
   * @param _totalClaimableRewards The total amount of rewards claimable for the epoch
   * @custom:reverts InvalidMerkleRoot when `_root == bytes32(0)`;
   *   InvalidTotalClaimableRewards when `_totalClaimableRewards == 0`;
   *   TotalClaimableRewardsCapExceeded when `_totalClaimableRewards` exceeds the per-epoch cap;
   *   MerkleRootAlreadyPublished when a root is already published for `_epoch`
   */
  function publishMerkleRoot(uint256 _epoch, bytes32 _root, uint256 _totalClaimableRewards) external;

  /**
   * @notice Permanently revokes a published Merkle root for an epoch
   * @dev Callable only by the owner (council). Final for that epoch: blocks further claims, zeros remaining
   *      `totalClaimableRewards`, and the epoch cannot be republished. Already-claimed rewards are unaffected.
   *      Use a new epoch to redistribute any unclaimed incentives.
   * @param _epoch The epoch whose Merkle root to revoke
   * @custom:reverts MerkleRootNotPublished when `_epoch` has no published root;
   *   MerkleRootAlreadyRevoked when `_epoch` is already revoked
   */
  function revokeMerkleRoot(uint256 _epoch) external;

  /**
   * @notice Allows a user to claim their rewards for specific epochs and a target
   * @dev `_epochs.length` must not exceed `MAX_EPOCHS_PER_CLAIM`.
   * @param _targetId The target ID for which rewards are being claimed
   * @param _epochs The epochs for which the user is claiming rewards
   * @param _amounts The amounts being claimed for each epoch
   * @param _proofs The Merkle proofs corresponding to each claim
   * @custom:reverts InvalidTargetId when `_targetId == bytes32(0)`;
   *   InvalidArrayLength when `_epochs`, `_amounts`, and `_proofs` lengths differ;
   *   TooManyEpochsPerClaim when `_epochs.length` exceeds `MAX_EPOCHS_PER_CLAIM`;
   *   InvalidMerkleRoot when a listed epoch has no published root;
   *   MerkleRootIsRevoked when a listed epoch's root is revoked;
   *   RewardAlreadyClaimed when the user already claimed for a listed target and epoch;
   *   TotalClaimableRewardsExceeded when a listed amount exceeds remaining epoch total;
   *   InvalidProof when a Merkle proof fails for a listed row
   */
  function claimUserRewards(
    bytes32 _targetId,
    uint256[] calldata _epochs,
    uint256[] calldata _amounts,
    bytes32[][] calldata _proofs
  ) external;

  /**
   * @notice Allows anyone to claim target rewards; GEO is sent to the PaymentManager
   * @dev `_epochs.length` must not exceed `MAX_EPOCHS_PER_CLAIM`.
   * @dev Effectively Space rewards; Topic targets are not currently expected to have payers.
   * @param _targetId The target ID for which rewards are being claimed
   * @param _epochs The epochs for which the target is claiming rewards
   * @param _amounts The amounts being claimed for each epoch
   * @param _proofs The Merkle proofs corresponding to each claim
   * @custom:reverts InvalidTargetId when `_targetId == bytes32(0)`;
   *   InvalidArrayLength when `_epochs`, `_amounts`, and `_proofs` lengths differ;
   *   TooManyEpochsPerClaim when `_epochs.length` exceeds `MAX_EPOCHS_PER_CLAIM`;
   *   InvalidMerkleRoot when a listed epoch has no published root;
   *   MerkleRootIsRevoked when a listed epoch's root is revoked;
   *   RewardAlreadyClaimed when the target already claimed for a listed epoch;
   *   TotalClaimableRewardsExceeded when a listed amount exceeds remaining epoch total;
   *   InvalidProof when a Merkle proof fails for a listed row
   */
  function claimTargetRewards(
    bytes32 _targetId,
    uint256[] calldata _epochs,
    uint256[] calldata _amounts,
    bytes32[][] calldata _proofs
  ) external;

  /**
   * @notice Returns the GEO incentives escrow
   * @return _escrow The escrow contract
   */
  function escrow() external view returns (IEscrow _escrow);

  /**
   * @notice Returns the address of the PaymentManager contract
   * @return _paymentManager The PaymentManager address
   */
  function paymentManager() external view returns (IPaymentManager _paymentManager);

  /**
   * @notice Returns the Merkle root for a given epoch
   * @param _epoch The epoch for which to return the Merkle root
   * @return _root The Merkle root for the specified epoch
   */
  function merkleRoot(uint256 _epoch) external view returns (bytes32 _root);

  /**
   * @notice Returns the total claimable rewards for a given epoch
   * @param _epoch The epoch for which to return the total claimable rewards
   * @return _amount The total claimable rewards for the specified epoch
   */
  function totalClaimableRewards(uint256 _epoch) external view returns (uint256 _amount);

  /**
   * @notice Returns whether a user has claimed rewards for a target for an epoch
   * @param _user The user address
   * @param _targetId The target ID
   * @param _epoch The epoch
   * @return _claimed Whether the user has claimed rewards
   */
  function userClaimed(address _user, bytes32 _targetId, uint256 _epoch) external view returns (bool _claimed);

  /**
   * @notice Returns whether a target has claimed rewards for an epoch
   * @param _targetId The target ID
   * @param _epoch The epoch
   * @return _claimed Whether the target has claimed rewards
   */
  function targetClaimed(bytes32 _targetId, uint256 _epoch) external view returns (bool _claimed);

  /**
   * @notice Returns whether a published Merkle root has been permanently revoked for an epoch
   * @param _epoch The epoch to query
   * @return _revoked Whether the epoch's Merkle root is revoked
   */
  function merkleRootRevoked(uint256 _epoch) external view returns (bool _revoked);

  /// @notice Sanity cap on total claimable GEO published for a single epoch
  /// @return _max The maximum total claimable GEO allowed per epoch
  function MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH() external pure returns (uint256 _max);

  /// @notice Maximum number of epochs that may be claimed in one call
  /// @return _max The maximum epochs per claim batch
  function MAX_EPOCHS_PER_CLAIM() external pure returns (uint8 _max);
}
