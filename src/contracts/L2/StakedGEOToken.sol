// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {VotesUpgradeable} from '@openzeppelin/contracts-upgradeable/governance/utils/VotesUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {
  ERC20VotesUpgradeable
} from '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol';
import {IVotes} from '@openzeppelin/contracts/governance/utils/IVotes.sol';
import {IERC6372} from '@openzeppelin/contracts/interfaces/IERC6372.sol';
import {Checkpoints} from '@openzeppelin/contracts/utils/structs/Checkpoints.sol';
import {Time} from '@openzeppelin/contracts/utils/types/Time.sol';

import {IStakedGEOToken} from 'interfaces/L2/IStakedGEOToken.sol';

/**
 * @title Staked GEO Token
 * @notice Soulbound staked-GEO voting token; minted and burned by `StakingManager`
 * @custom:security WARNING: This contract has not been audited, and may contain bugs.
 */
contract StakedGEOToken is ERC20VotesUpgradeable, OwnableUpgradeable, UUPSUpgradeable, IStakedGEOToken {
  /**
   * @notice ERC-7201 namespaced storage slot for the StakedGEOToken contract
   * @custom:storage-location erc7201:geo.storage.StakedGEOToken
   * @dev Computed with: keccak256(abi.encode(uint256(keccak256("geo.storage.StakedGEOToken")) - 1)) & ~bytes32(uint256(0xff))
   */
  bytes32 internal constant _STAKED_GEO_TOKEN_STORAGE_LOCATION =
    0x20eef0e511023dbaaa0bd247d0969b73b88a783d42c564b6a066a2623a1af700;

  /**
   * @notice Restricts access to the configured `StakingManager`
   * @dev Reverts if caller is not `stakingManager`.
   */
  modifier onlyStakingManager() virtual {
    if (msg.sender != _getStakedGEOTokenStorage().stakingManager) revert OnlyStakingManager();
    _;
  }

  /**
   * @notice Constructor
   * @custom:oz-upgrades-unsafe-allow constructor
   */
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IStakedGEOToken
  function initialize(StakedGEOTokenInitializationParams calldata _initParams) external virtual initializer {
    if (_initParams.stakingManager == address(0)) revert InvalidAddress();

    __Ownable_init(_initParams.council);
    __UUPSUpgradeable_init();
    __ERC20_init('Staked GEO Token', 'stkGEO');
    __ERC20Votes_init();

    StakedGEOTokenStorage storage $_ = _getStakedGEOTokenStorage();
    $_.stakingManager = _initParams.stakingManager;
  }

  /// @inheritdoc IStakedGEOToken
  function mint(address _to, uint256 _amount) external virtual onlyStakingManager {
    if (_amount == 0) revert ZeroAmount();
    _mint(_to, _amount);
  }

  /// @inheritdoc IStakedGEOToken
  function burn(address _from, uint256 _amount) external virtual onlyStakingManager {
    if (_amount == 0) revert ZeroAmount();
    _burn(_from, _amount);
  }

  /// @inheritdoc IStakedGEOToken
  function getStakeEligibleSince(address _account) external view virtual returns (uint256 _sinceTimestamp) {
    if (getVotes(_account) == 0) return 0;
    _sinceTimestamp = _findStakeEligibleSince(_account, clock());
  }

  /// @inheritdoc IStakedGEOToken
  function getPastStakeEligibleSince(
    address _account,
    uint256 _timepoint
  ) external view virtual returns (uint256 _sinceTimestamp) {
    if (getPastVotes(_account, _timepoint) == 0) return 0;
    _sinceTimestamp = _findStakeEligibleSince(_account, _timepoint);
  }

  /// @inheritdoc IStakedGEOToken
  function stakingManager() external view returns (address _stakingManager) {
    _stakingManager = _getStakedGEOTokenStorage().stakingManager;
  }

  /// @inheritdoc VotesUpgradeable
  function delegate(
    address /* _delegatee */
  ) public virtual override(IVotes, VotesUpgradeable) {
    revert DelegationDisabled();
  }

  /// @inheritdoc VotesUpgradeable
  function delegateBySig(
    address,
    /* _delegatee */
    uint256,
    /* _nonce */
    uint256,
    /* _expiry */
    uint8,
    /* _v */
    bytes32,
    /* _r */
    bytes32 /* _s */
  ) public virtual override(IVotes, VotesUpgradeable) {
    revert DelegationDisabled();
  }

  /// @inheritdoc VotesUpgradeable
  function clock() public view virtual override(IERC6372, VotesUpgradeable) returns (uint48) {
    return Time.timestamp();
  }

  /// @inheritdoc VotesUpgradeable
  function CLOCK_MODE() public pure virtual override(IERC6372, VotesUpgradeable) returns (string memory) {
    return 'mode=timestamp';
  }

  /// @inheritdoc IStakedGEOToken
  function typeId() public pure virtual returns (bytes32 _typeId) {
    _typeId = keccak256(bytes('STAKED_GEO_TOKEN'));
  }

  /// @inheritdoc IStakedGEOToken
  function version() public pure virtual returns (string memory _version) {
    _version = '1.0.0';
  }

  /**
   * @inheritdoc ERC20VotesUpgradeable
   * @dev Reverts on peer transfers; auto-self-delegates recipients so vote checkpoints track balance
   */
  function _update(address _from, address _to, uint256 _value) internal virtual override {
    if (_from != address(0) && _to != address(0)) revert SoulboundTransfer();
    if (_to != address(0) && delegates(_to) == address(0)) _delegate(_to, _to);
    super._update(_from, _to, _value);
  }

  /**
   * @inheritdoc UUPSUpgradeable
   * @dev Function that should revert when msg.sender is not authorized to upgrade the contract
   */
  function _authorizeUpgrade(
    address /* _newImplementation */
  ) internal virtual override onlyOwner {}

  /**
   * @notice Finds the timestamp where the account's current non-zero balance streak began at or before `_timepoint`
   * @dev Returns 0 instead of reverting when nothing is found at or before `_timepoint`. Zero does not necessarily
   * mean the account has never staked.
   * @param _account The account to query
   * @param _timepoint Historical timestamp per {clock}
   * @return _sinceTimestamp Timestamp of the streak start
   */
  function _findStakeEligibleSince(
    address _account,
    uint256 _timepoint
  ) internal view virtual returns (uint256 _sinceTimestamp) {
    uint32 _checkpointIndex = _findCheckpointAtOrBefore(_account, _timepoint);
    Checkpoints.Checkpoint208 memory _checkpoint = checkpoints(_account, _checkpointIndex);

    if (_checkpoint._key > _timepoint) {
      return 0;
    }

    while (_checkpointIndex > 0) {
      Checkpoints.Checkpoint208 memory _previousCheckpoint = checkpoints(_account, _checkpointIndex - 1);
      if (_previousCheckpoint._value == 0) {
        return _checkpoint._key;
      }
      _checkpoint = _previousCheckpoint;
      _checkpointIndex--;
    }

    if (_checkpoint._value > 0) {
      return _checkpoint._key;
    }
  }

  /**
   * @notice Returns the index of the last checkpoint with `_key <= _timepoint`
   * @dev Returns 0 instead of reverting when no checkpoint at or before `_timepoint` is found. Zero does not
   * necessarily mean the account has no checkpoints; the account may have staked later, or checkpoint 0 may be
   * after `_timepoint`.
   * @param _account The account to query
   * @param _timepoint Historical timestamp per {clock}
   * @return _checkpointIndex Index into the account checkpoint trace
   */
  function _findCheckpointAtOrBefore(
    address _account,
    uint256 _timepoint
  ) internal view virtual returns (uint32 _checkpointIndex) {
    uint32 _high = numCheckpoints(_account);
    if (_high == 0) return 0;

    _checkpointIndex = _high - 1;
    uint32 _low = 0;

    while (_low < _checkpointIndex) {
      uint32 _mid = _low + (_checkpointIndex - _low + 1) / 2;
      if (checkpoints(_account, _mid)._key <= _timepoint) {
        _low = _mid;
      } else {
        _checkpointIndex = _mid - 1;
      }
    }
  }

  /**
   * @notice Returns the ERC-7201 namespaced storage pointer for StakedGEOToken
   * @return $_ Namespaced storage for StakedGEOToken
   * @custom:storage-location erc7201:geo.storage.StakedGEOToken
   */
  function _getStakedGEOTokenStorage() internal pure returns (StakedGEOTokenStorage storage $_) {
    assembly {
      $_.slot := _STAKED_GEO_TOKEN_STORAGE_LOCATION
    }
  }
}
