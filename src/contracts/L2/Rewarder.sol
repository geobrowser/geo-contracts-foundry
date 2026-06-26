// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {MerkleProof} from '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

import {IEscrow} from 'interfaces/L2/IEscrow.sol';
import {IPaymentManager} from 'interfaces/L2/IPaymentManager.sol';
import {IRewarder} from 'interfaces/L2/IRewarder.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title Rewarder
 * @notice Distributes GEO incentives from escrow using per-epoch Merkle roots for users and targets
 * @custom:security WARNING: This contract has not been audited, and may contain bugs.
 */
contract Rewarder is OwnableUpgradeable, UUPSUpgradeable, IRewarder {
  /// @inheritdoc IRewarder
  uint256 public constant MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH = 100_000_000e18;

  /// @inheritdoc IRewarder
  uint8 public constant MAX_EPOCHS_PER_CLAIM = 50;

  /**
   * @notice ERC-7201 namespaced storage slot for the Rewarder contract
   * @custom:storage-location erc7201:geo.storage.Rewarder
   * @dev Computed with: keccak256(abi.encode(uint256(keccak256("geo.storage.Rewarder")) - 1)) & ~bytes32(uint256(0xff))
   */
  bytes32 internal constant _REWARDER_STORAGE_LOCATION =
    0x27b8fa062468ee2b702e31ab538d56d1febd447184f12585d5404481d2a32b00;

  /**
   * @notice Constructor
   * @custom:oz-upgrades-unsafe-allow constructor
   */
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IRewarder
  function initialize(RewarderInitializationParams calldata _initParams) external virtual initializer {
    if (_initParams.escrow == address(0) || _initParams.paymentManager == address(0)) revert InvalidAddress();

    __Ownable_init(_initParams.council);
    __UUPSUpgradeable_init();

    RewarderStorage storage $_ = _getRewarderStorage();
    $_.escrow = IEscrow(_initParams.escrow);
    $_.paymentManager = IPaymentManager(_initParams.paymentManager);
  }

  /// @inheritdoc IRewarder
  function publishMerkleRoot(uint256 _epoch, bytes32 _root, uint256 _totalClaimableRewards) external virtual onlyOwner {
    if (_root == bytes32(0)) revert InvalidMerkleRoot();
    if (_totalClaimableRewards == 0) revert InvalidTotalClaimableRewards();
    if (_totalClaimableRewards > MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH) revert TotalClaimableRewardsCapExceeded();

    RewarderStorage storage $_ = _getRewarderStorage();
    if ($_.merkleRoot[_epoch] != bytes32(0)) revert MerkleRootAlreadyPublished();

    $_.merkleRoot[_epoch] = _root;
    $_.totalClaimableRewards[_epoch] = _totalClaimableRewards;

    emit MerkleRootPublished(_epoch, _root, _totalClaimableRewards);
  }

  /// @inheritdoc IRewarder
  function revokeMerkleRoot(uint256 _epoch) external virtual onlyOwner {
    RewarderStorage storage $_ = _getRewarderStorage();
    if ($_.merkleRoot[_epoch] == bytes32(0)) revert MerkleRootNotPublished();
    if ($_.merkleRootRevoked[_epoch]) revert MerkleRootAlreadyRevoked();

    $_.merkleRootRevoked[_epoch] = true;
    $_.totalClaimableRewards[_epoch] = 0;

    emit MerkleRootRevoked(_epoch);
  }

  /// @inheritdoc IRewarder
  function claimUserRewards(
    bytes32 _targetId,
    uint256[] calldata _epochs,
    uint256[] calldata _amounts,
    bytes32[][] calldata _proofs
  ) external virtual {
    if (_targetId == bytes32(0)) revert InvalidTargetId();

    uint256 _arrayLength = _epochs.length;
    if (_arrayLength != _amounts.length || _arrayLength != _proofs.length) revert InvalidArrayLength();
    if (_arrayLength > MAX_EPOCHS_PER_CLAIM) revert TooManyEpochsPerClaim();

    RewarderStorage storage $_ = _getRewarderStorage();
    address _claimer = msg.sender;
    uint256 _totalClaimAmount;

    for (uint256 _i; _i < _arrayLength; ++_i) {
      _totalClaimAmount += _claimSingleUserReward($_, _claimer, _targetId, _epochs[_i], _amounts[_i], _proofs[_i]);
    }

    if (_totalClaimAmount > 0) {
      _pullGeo(_claimer, _totalClaimAmount);
    }
  }

  /// @inheritdoc IRewarder
  function claimTargetRewards(
    bytes32 _targetId,
    uint256[] calldata _epochs,
    uint256[] calldata _amounts,
    bytes32[][] calldata _proofs
  ) external virtual {
    if (_targetId == bytes32(0)) revert InvalidTargetId();

    uint256 _arrayLength = _epochs.length;
    if (_arrayLength != _amounts.length || _arrayLength != _proofs.length) revert InvalidArrayLength();
    if (_arrayLength > MAX_EPOCHS_PER_CLAIM) revert TooManyEpochsPerClaim();

    RewarderStorage storage $_ = _getRewarderStorage();
    uint256 _totalClaimAmount;

    for (uint256 _i; _i < _arrayLength; ++_i) {
      _totalClaimAmount += _claimSingleTargetReward($_, _targetId, _epochs[_i], _amounts[_i], _proofs[_i]);
    }

    if (_totalClaimAmount > 0) {
      address _paymentManager = address($_.paymentManager);
      _pullGeo(_paymentManager, _totalClaimAmount);
      $_.paymentManager.processRewards(_targetId, _totalClaimAmount);
    }
  }

  /// @inheritdoc IRewarder
  function escrow() external view returns (IEscrow _escrow) {
    _escrow = _getRewarderStorage().escrow;
  }

  /// @inheritdoc IRewarder
  function paymentManager() external view returns (IPaymentManager _paymentManager) {
    _paymentManager = _getRewarderStorage().paymentManager;
  }

  /// @inheritdoc IRewarder
  function merkleRoot(uint256 _epoch) external view returns (bytes32 _root) {
    _root = _getRewarderStorage().merkleRoot[_epoch];
  }

  /// @inheritdoc IRewarder
  function totalClaimableRewards(uint256 _epoch) external view returns (uint256 _amount) {
    _amount = _getRewarderStorage().totalClaimableRewards[_epoch];
  }

  /// @inheritdoc IRewarder
  function userClaimed(address _user, bytes32 _targetId, uint256 _epoch) external view returns (bool _claimed) {
    _claimed = _getRewarderStorage().userClaimed[_user][_targetId][_epoch];
  }

  /// @inheritdoc IRewarder
  function targetClaimed(bytes32 _targetId, uint256 _epoch) external view returns (bool _claimed) {
    _claimed = _getRewarderStorage().targetClaimed[_targetId][_epoch];
  }

  /// @inheritdoc IRewarder
  function merkleRootRevoked(uint256 _epoch) external view returns (bool _revoked) {
    _revoked = _getRewarderStorage().merkleRootRevoked[_epoch];
  }

  /// @inheritdoc ISemver
  function typeId() public pure virtual returns (bytes32 _type) {
    _type = keccak256(bytes(name()));
  }

  /// @inheritdoc ISemver
  function name() public pure virtual returns (string memory _name) {
    _name = 'REWARDER';
  }

  /// @inheritdoc ISemver
  function version() public pure virtual returns (string memory _version) {
    _version = '1.0.0';
  }

  /**
   * @inheritdoc UUPSUpgradeable
   * @dev Function that should revert when msg.sender is not authorized to upgrade the contract
   */
  function _authorizeUpgrade(
    address /* _newImplementation */
  ) internal virtual override onlyOwner {}

  /**
   * @notice Pulls GEO incentives from escrow to a recipient
   * @param _to The recipient
   * @param _amount The amount to pull
   */
  function _pullGeo(address _to, uint256 _amount) internal virtual {
    _getRewarderStorage().escrow.pull(_to, _amount);
  }

  /**
   * @notice Validates and records a single user reward claim row (caller pulls once after batching)
   * @param $_ Rewarder storage pointer
   * @param _claimer The address encoded in the Merkle leaf (the reward recipient)
   * @param _targetId Target identifier encoded in the Merkle leaf
   * @param _epoch Epoch encoded in the Merkle leaf
   * @param _amount Amount encoded in the Merkle leaf
   * @param _proof Merkle proof for the leaf
   * @return _claimedAmount The amount recorded for this row
   */
  function _claimSingleUserReward(
    RewarderStorage storage $_,
    address _claimer,
    bytes32 _targetId,
    uint256 _epoch,
    uint256 _amount,
    bytes32[] calldata _proof
  ) internal virtual returns (uint256 _claimedAmount) {
    bytes32 _leaf = keccak256(abi.encodePacked(_claimer, _targetId, _epoch, _amount));

    if ($_.merkleRoot[_epoch] == bytes32(0)) revert InvalidMerkleRoot();
    if ($_.merkleRootRevoked[_epoch]) revert MerkleRootIsRevoked();
    if ($_.userClaimed[_claimer][_targetId][_epoch]) revert RewardAlreadyClaimed();
    if (_amount > $_.totalClaimableRewards[_epoch]) revert TotalClaimableRewardsExceeded();
    if (!MerkleProof.verifyCalldata(_proof, $_.merkleRoot[_epoch], _leaf)) revert InvalidProof();

    $_.userClaimed[_claimer][_targetId][_epoch] = true;
    $_.totalClaimableRewards[_epoch] -= _amount;

    emit UserRewardsClaimed(_claimer, _targetId, _epoch, _amount);

    return _amount;
  }

  /**
   * @notice Validates and records a single target reward claim row
   * @param $_ Rewarder storage pointer
   * @param _targetId Target identifier encoded in the Merkle leaf
   * @param _epoch Epoch encoded in the Merkle leaf
   * @param _amount Amount encoded in the Merkle leaf
   * @param _proof Merkle proof for the leaf
   * @return _claimedAmount The claimed amount for this row
   */
  function _claimSingleTargetReward(
    RewarderStorage storage $_,
    bytes32 _targetId,
    uint256 _epoch,
    uint256 _amount,
    bytes32[] calldata _proof
  ) internal virtual returns (uint256 _claimedAmount) {
    bytes32 _leaf = keccak256(abi.encodePacked(_targetId, _epoch, _amount));

    if ($_.merkleRoot[_epoch] == bytes32(0)) revert InvalidMerkleRoot();
    if ($_.merkleRootRevoked[_epoch]) revert MerkleRootIsRevoked();
    if ($_.targetClaimed[_targetId][_epoch]) revert RewardAlreadyClaimed();
    if (_amount > $_.totalClaimableRewards[_epoch]) revert TotalClaimableRewardsExceeded();
    if (!MerkleProof.verifyCalldata(_proof, $_.merkleRoot[_epoch], _leaf)) revert InvalidProof();

    $_.targetClaimed[_targetId][_epoch] = true;
    $_.totalClaimableRewards[_epoch] -= _amount;

    emit TargetRewardsClaimed(_targetId, _epoch, _amount);

    return _amount;
  }

  /**
   * @notice Returns the ERC-7201 namespaced storage pointer for Rewarder
   * @return $_ Namespaced storage for Rewarder
   * @custom:storage-location erc7201:geo.storage.Rewarder
   */
  function _getRewarderStorage() internal pure returns (RewarderStorage storage $_) {
    assembly {
      $_.slot := _REWARDER_STORAGE_LOCATION
    }
  }
}
