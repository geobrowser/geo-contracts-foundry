// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {IERC5267} from '@openzeppelin/contracts/interfaces/IERC5267.sol';
import {IERC5805} from '@openzeppelin/contracts/interfaces/IERC5805.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

/**
 * @title IStakedGEOToken
 * @notice Interface for the soulbound staked-GEO voting token minted and burned by `StakingManager`
 */
interface IStakedGEOToken is IERC20Metadata, IERC5267, IERC5805 {
  /**
   * @notice ERC-7201 namespaced storage for StakedGEOToken.
   * @param stakingManager The sole authorized minter and burner after initialization
   * @custom:storage-location erc7201:geo.storage.StakedGEOToken
   */
  struct StakedGEOTokenStorage {
    address stakingManager;
  }

  /**
   * @notice Parameters required for initializing the StakedGEOToken contract
   * @param council Address of the council (owner)
   * @param stakingManager Authorized `StakingManager` proxy (must be non-zero)
   */
  struct StakedGEOTokenInitializationParams {
    address council;
    address stakingManager;
  }

  /// @notice Thrown when the caller is not the configured `StakingManager`
  error OnlyStakingManager();

  /// @notice Thrown when the provided address is invalid
  error InvalidAddress();

  /// @notice Thrown when a transfer or transferFrom is attempted outside mint/burn paths
  error SoulboundTransfer();

  /// @notice Thrown when delegation is attempted
  error DelegationDisabled();

  /// @notice Thrown when a zero token amount is invalid
  error ZeroAmount();

  /**
   * @notice Initializes the StakedGEOToken contract behind a UUPS proxy
   * @dev Callable only once during proxy deployment.
   * @param _initParams Council (owner) and `StakingManager` addresses
   * @custom:reverts InvalidAddress when `stakingManager` is zero
   */
  function initialize(StakedGEOTokenInitializationParams calldata _initParams) external;

  /**
   * @notice Mints `stkGEO` to `_to`
   * @dev Callable only by `stakingManager`.
   * @param _to Recipient of the minted voting units
   * @param _amount Amount of `stkGEO` to mint
   * @custom:reverts ZeroAmount when `_amount == 0`
   */
  function mint(address _to, uint256 _amount) external;

  /**
   * @notice Burns `stkGEO` from `_from`
   * @dev Callable only by `stakingManager`.
   * @param _from Account whose balance is reduced
   * @param _amount Amount of `stkGEO` to burn
   * @custom:reverts ZeroAmount when `_amount == 0`
   */
  function burn(address _from, uint256 _amount) external;

  /**
   * @notice Returns the timestamp at which the account's current non-zero balance streak began
   * @dev Derived from `ERC20Votes` checkpoint history. A return of `0` means the account has no
   * votes now, not that it has never staked.
   * @param _account The account to query
   * @return _sinceTimestamp Timestamp of the last `0 → non-zero` transition for the current streak
   */
  function getStakeEligibleSince(address _account) external view returns (uint256 _sinceTimestamp);

  /**
   * @notice Returns the timestamp at which the account's current non-zero balance streak began at or before `_timepoint`
   * @dev Derived from `ERC20Votes` checkpoint history. A return of 0 means the account had no votes at
   * `_timepoint`, not that it has never staked.
   * @param _account The account to query
   * @param _timepoint Historical timestamp (`uint48` semantics per {clock})
   * @return _sinceTimestamp Timestamp of the last `0 → non-zero` transition at or before `_timepoint`
   */
  function getPastStakeEligibleSince(
    address _account,
    uint256 _timepoint
  ) external view returns (uint256 _sinceTimestamp);

  /**
   * @notice Returns the configured `StakingManager` authorized to mint and burn
   * @return _stakingManager The `StakingManager` address
   */
  function stakingManager() external view returns (address _stakingManager);

  /**
   * @notice Returns the semantic type identifier of the contract
   * @return _typeId The type identifier (`keccak256(bytes('STAKED_GEO_TOKEN'))`)
   */
  function typeId() external pure returns (bytes32 _typeId);

  /**
   * @notice Returns the semantic version of the contract
   * @return _version The semantic version string
   */
  function version() external pure returns (string memory _version);
}
