// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {IStakedGEOToken} from 'interfaces/L2/IStakedGEOToken.sol';
import {IStakingManager} from 'interfaces/L2/IStakingManager.sol';
import {IStakingRegistry} from 'interfaces/L2/IStakingRegistry.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title StakingManager
 * @notice Custodies staked GEO and user allocations
 * @custom:security WARNING: This contract has not been audited, and may contain bugs.
 */
contract StakingManager is OwnableUpgradeable, UUPSUpgradeable, IStakingManager {
  using SafeERC20 for IERC20;
  /**
   * @notice ERC-7201 namespaced storage slot for the StakingManager contract
   * @custom:storage-location erc7201:geo.storage.StakingManager
   * @dev Computed with: keccak256(abi.encode(uint256(keccak256("geo.storage.StakingManager")) - 1)) & ~bytes32(uint256(0xff))
   */
  bytes32 internal constant _STAKING_MANAGER_STORAGE_LOCATION =
    0x930c9975b5f5e254e041c38c74779d872cfebf771eb562c841fd1d9ecf721e00;

  /// @inheritdoc IStakingManager
  uint256 public constant MAX_UNSTAKE_REQUEST_DELAY = 30 days;

  /**
   * @notice Constructor
   * @custom:oz-upgrades-unsafe-allow constructor
   */
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IStakingManager
  function initialize(StakingManagerInitializationParams calldata _initParams) external virtual initializer {
    if (
      _initParams.arbitrumGeoToken == address(0) || _initParams.stakingRegistry == address(0)
        || _initParams.stakedGEOToken == address(0)
    ) {
      revert InvalidAddress();
    }

    __Ownable_init(_initParams.council);
    __UUPSUpgradeable_init();

    StakingManagerStorage storage $_ = _getStakingManagerStorage();
    $_.arbitrumGeoToken = IERC20(_initParams.arbitrumGeoToken);
    $_.stakingRegistry = IStakingRegistry(_initParams.stakingRegistry);
    $_.stakedGEOToken = IStakedGEOToken(_initParams.stakedGEOToken);

    _setMinAmount(_initParams.minAmount);
    _setUnstakeRequestDelay(_initParams.unstakeRequestDelay);
  }

  /// @inheritdoc IStakingManager
  function setMinAmount(uint256 _minAmount) external virtual onlyOwner {
    _setMinAmount(_minAmount);
  }

  /// @inheritdoc IStakingManager
  function setUnstakeRequestDelay(uint256 _unstakeRequestDelay) external virtual onlyOwner {
    _setUnstakeRequestDelay(_unstakeRequestDelay);
  }

  /// @inheritdoc IStakingManager
  function stake(uint256 _amount) external virtual {
    _stake(msg.sender, msg.sender, _amount);
  }

  /// @inheritdoc IStakingManager
  function stakeFor(address _recipient, uint256 _amount) external virtual {
    if (_recipient == address(0)) revert InvalidAddress();
    _stake(msg.sender, _recipient, _amount);
  }

  /// @inheritdoc IStakingManager
  function requestUnstake(uint256 _amount) external virtual returns (uint256 _unstakeId) {
    StakingManagerStorage storage $_ = _getStakingManagerStorage();
    if (_amount == 0) revert ZeroAmount();

    uint256 _totalUserDisposableStake = _calculateTotalUserDisposableStake($_, msg.sender);
    if (_amount > _totalUserDisposableStake) revert InsufficientDisposableStake();
    if (_amount < $_.minAmount && _amount != _totalUserDisposableStake) revert AmountBelowMinimum();

    uint256 _remainderDisposableStake = _totalUserDisposableStake - _amount;
    if (_remainderDisposableStake != 0 && _remainderDisposableStake < $_.minAmount) {
      revert DisposableStakeRemainderBelowMinimum();
    }

    uint256 _unlockTime = block.timestamp + $_.unstakeRequestDelay;

    _unstakeId = $_.unstakeRequestNonce++;
    $_.unstakeRequests[_unstakeId] = UnstakeRequest({user: msg.sender, amount: _amount, unlockTime: _unlockTime});

    $_.totalUserPendingUnstake[msg.sender] += _amount;
    $_.totalPendingUnstake += _amount;

    emit UnstakeRequested(_unstakeId, msg.sender, _amount, _unlockTime);
  }

  /// @inheritdoc IStakingManager
  function unstake(uint256 _unstakeId) external virtual {
    StakingManagerStorage storage $_ = _getStakingManagerStorage();
    UnstakeRequest memory _unstakeRequest = $_.unstakeRequests[_unstakeId];
    if (_unstakeRequest.user == address(0)) revert UnstakeRequestNotFound();
    if (msg.sender != _unstakeRequest.user) revert UnstakeRequestUnauthorized();
    if (block.timestamp < _unstakeRequest.unlockTime) revert UnstakeRequestLocked();

    uint256 _amount = _unstakeRequest.amount;

    $_.totalUserStake[msg.sender] -= _amount;
    $_.totalStaked -= _amount;
    $_.totalUserPendingUnstake[msg.sender] -= _amount;
    $_.totalPendingUnstake -= _amount;
    delete $_.unstakeRequests[_unstakeId];

    $_.stakedGEOToken.burn(msg.sender, _amount);

    $_.arbitrumGeoToken.safeTransfer(msg.sender, _amount);

    emit Unstaked(_unstakeId);
  }

  /// @inheritdoc IStakingManager
  function allocate(bytes32 _targetId, uint256 _amount) external virtual {
    StakingManagerStorage storage $_ = _getStakingManagerStorage();

    uint256 _totalUserDisposableStake = _calculateTotalUserDisposableStake($_, msg.sender);
    if (_amount > _totalUserDisposableStake) revert InsufficientDisposableStake();
    if (_amount < $_.minAmount) revert AmountBelowMinimum();

    _requireActiveAllocationTarget($_, _targetId);

    $_.allocations[msg.sender][_targetId] += _amount;
    $_.totalUserAllocation[msg.sender] += _amount;
    $_.totalTargetAllocation[_targetId] += _amount;
    $_.totalAllocated += _amount;

    emit Allocated(msg.sender, _targetId, _amount);
  }

  /// @inheritdoc IStakingManager
  function deallocate(bytes32 _targetId, uint256 _amount) external virtual {
    StakingManagerStorage storage $_ = _getStakingManagerStorage();
    if (_amount == 0) revert ZeroAmount();

    uint256 _allocated = $_.allocations[msg.sender][_targetId];
    if (_amount > _allocated) revert InsufficientAllocation();
    if (_amount < $_.minAmount && _amount != _allocated) revert AmountBelowMinimum();

    uint256 _remainderAllocation = _allocated - _amount;
    if (_remainderAllocation != 0 && _remainderAllocation < $_.minAmount) revert AllocationRemainderBelowMinimum();

    $_.allocations[msg.sender][_targetId] -= _amount;
    $_.totalUserAllocation[msg.sender] -= _amount;
    $_.totalTargetAllocation[_targetId] -= _amount;
    $_.totalAllocated -= _amount;

    emit Deallocated(msg.sender, _targetId, _amount);
  }

  /// @inheritdoc IStakingManager
  function reallocate(bytes32 _fromTargetId, bytes32 _toTargetId, uint256 _amount) external virtual {
    if (_fromTargetId == _toTargetId) revert SameReallocationTargets();

    StakingManagerStorage storage $_ = _getStakingManagerStorage();

    uint256 _allocatedFrom = $_.allocations[msg.sender][_fromTargetId];
    if (_amount > _allocatedFrom) revert InsufficientAllocation();
    if (_amount < $_.minAmount) revert AmountBelowMinimum();

    uint256 _remainderOnSource = _allocatedFrom - _amount;
    if (_remainderOnSource != 0 && _remainderOnSource < $_.minAmount) revert AllocationRemainderBelowMinimum();

    _requireActiveAllocationTarget($_, _toTargetId);

    $_.allocations[msg.sender][_fromTargetId] -= _amount;
    $_.totalTargetAllocation[_fromTargetId] -= _amount;

    $_.allocations[msg.sender][_toTargetId] += _amount;
    $_.totalTargetAllocation[_toTargetId] += _amount;

    emit Reallocated(msg.sender, _fromTargetId, _toTargetId, _amount);
  }

  /// @inheritdoc IStakingManager
  function arbitrumGeoToken() external view returns (IERC20 _arbitrumGeoToken) {
    _arbitrumGeoToken = _getStakingManagerStorage().arbitrumGeoToken;
  }

  /// @inheritdoc IStakingManager
  function stakingRegistry() external view returns (IStakingRegistry _stakingRegistry) {
    _stakingRegistry = _getStakingManagerStorage().stakingRegistry;
  }

  /// @inheritdoc IStakingManager
  function stakedGEOToken() external view returns (IStakedGEOToken _stakedGEOToken) {
    _stakedGEOToken = _getStakingManagerStorage().stakedGEOToken;
  }

  /// @inheritdoc IStakingManager
  function minAmount() external view returns (uint256 _minAmount) {
    _minAmount = _getStakingManagerStorage().minAmount;
  }

  /// @inheritdoc IStakingManager
  function unstakeRequestDelay() external view returns (uint256 _unstakeRequestDelay) {
    _unstakeRequestDelay = _getStakingManagerStorage().unstakeRequestDelay;
  }

  /// @inheritdoc IStakingManager
  function totalStaked() external view returns (uint256 _totalStaked) {
    _totalStaked = _getStakingManagerStorage().totalStaked;
  }

  /// @inheritdoc IStakingManager
  function totalPendingUnstake() external view returns (uint256 _totalPendingUnstake) {
    _totalPendingUnstake = _getStakingManagerStorage().totalPendingUnstake;
  }

  /// @inheritdoc IStakingManager
  function totalAllocated() external view returns (uint256 _totalAllocated) {
    _totalAllocated = _getStakingManagerStorage().totalAllocated;
  }

  /// @inheritdoc IStakingManager
  function unstakeRequestNonce() external view returns (uint256 _unstakeRequestNonce) {
    _unstakeRequestNonce = _getStakingManagerStorage().unstakeRequestNonce;
  }

  /// @inheritdoc IStakingManager
  function totalUserStake(address _user) external view returns (uint256 _amount) {
    _amount = _getStakingManagerStorage().totalUserStake[_user];
  }

  /// @inheritdoc IStakingManager
  function totalUserPendingUnstake(address _user) external view returns (uint256 _amount) {
    _amount = _getStakingManagerStorage().totalUserPendingUnstake[_user];
  }

  /// @inheritdoc IStakingManager
  function unstakeRequests(uint256 _unstakeId) external view returns (UnstakeRequest memory _unstakeRequest) {
    _unstakeRequest = _getStakingManagerStorage().unstakeRequests[_unstakeId];
  }

  /// @inheritdoc IStakingManager
  function totalUserAllocation(address _user) external view returns (uint256 _amount) {
    _amount = _getStakingManagerStorage().totalUserAllocation[_user];
  }

  /// @inheritdoc IStakingManager
  function totalUserDisposableStake(address _user) external view returns (uint256 _disposableStake) {
    StakingManagerStorage storage $_ = _getStakingManagerStorage();
    _disposableStake = _calculateTotalUserDisposableStake($_, _user);
  }

  /// @inheritdoc IStakingManager
  function totalTargetAllocation(bytes32 _targetId) external view returns (uint256 _amount) {
    _amount = _getStakingManagerStorage().totalTargetAllocation[_targetId];
  }

  /// @inheritdoc IStakingManager
  function allocations(address _user, bytes32 _targetId) external view returns (uint256 _amount) {
    _amount = _getStakingManagerStorage().allocations[_user][_targetId];
  }

  /// @inheritdoc ISemver
  function typeId() public pure virtual returns (bytes32 _type) {
    _type = keccak256(bytes(name()));
  }

  /// @inheritdoc ISemver
  function name() public pure virtual returns (string memory _name) {
    _name = 'STAKING_MANAGER';
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
   * @notice Credits staked GEO to `_recipient` after pulling tokens from `_staker`
   * @param _staker The account `arbitrumGeoToken` is pulled from
   * @param _recipient The account to credit with staked GEO
   * @param _amount The amount of GEO tokens to stake
   */
  function _stake(address _staker, address _recipient, uint256 _amount) internal virtual {
    StakingManagerStorage storage $_ = _getStakingManagerStorage();
    if (_amount < $_.minAmount) revert AmountBelowMinimum();

    $_.totalUserStake[_recipient] += _amount;
    $_.totalStaked += _amount;

    $_.arbitrumGeoToken.safeTransferFrom(_staker, address(this), _amount);

    $_.stakedGEOToken.mint(_recipient, _amount);

    emit Staked(_staker, _recipient, _amount);
  }

  /**
   * @notice Sets the minimum interaction amount
   * @param _minAmount The new minimum amount
   * @dev Reverts with `ZeroAmount` when `_minAmount` is zero so interaction checks cannot be bypassed
   */
  function _setMinAmount(uint256 _minAmount) internal virtual {
    if (_minAmount == 0) revert ZeroAmount();
    _getStakingManagerStorage().minAmount = _minAmount;
    emit MinAmountSet(_minAmount);
  }

  /**
   * @notice Sets the unstake request delay
   * @param _unstakeRequestDelay The new unstake request delay
   */
  function _setUnstakeRequestDelay(uint256 _unstakeRequestDelay) internal virtual {
    if (_unstakeRequestDelay > MAX_UNSTAKE_REQUEST_DELAY) revert UnstakeRequestDelayExceedsMaximum();
    _getStakingManagerStorage().unstakeRequestDelay = _unstakeRequestDelay;
    emit UnstakeRequestDelaySet(_unstakeRequestDelay);
  }

  /**
   * @notice Computes total disposable stake for a user (stake minus pending unstake minus allocations)
   * @param $_ StakingManager storage
   * @param _user The user address
   * @return _totalUserDisposableStake The user's disposable stake
   */
  function _calculateTotalUserDisposableStake(
    StakingManagerStorage storage $_,
    address _user
  ) internal view virtual returns (uint256 _totalUserDisposableStake) {
    _totalUserDisposableStake =
      $_.totalUserStake[_user] - $_.totalUserPendingUnstake[_user] - $_.totalUserAllocation[_user];
  }

  /**
   * @notice Reverts unless `_targetId` is active in the configured `StakingRegistry`
   * @param $_ StakingManager storage
   * @param _targetId Target id to validate for a new or increased allocation
   */
  function _requireActiveAllocationTarget(StakingManagerStorage storage $_, bytes32 _targetId) internal view virtual {
    if (!$_.stakingRegistry.targets(_targetId).tActive) revert InactiveAllocationTarget();
  }

  /**
   * @notice Returns the ERC-7201 namespaced storage pointer for StakingManager
   * @return $_ Namespaced storage for StakingManager
   * @custom:storage-location erc7201:geo.storage.StakingManager
   */
  function _getStakingManagerStorage() internal pure returns (StakingManagerStorage storage $_) {
    assembly {
      $_.slot := _STAKING_MANAGER_STORAGE_LOCATION
    }
  }
}
