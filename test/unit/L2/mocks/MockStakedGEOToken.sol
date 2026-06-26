// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {StakedGEOToken} from 'contracts/L2/StakedGEOToken.sol';

/**
 * @title MockStakedGEOToken
 * @notice Test helper exposing ERC-7201 storage location for unit tests.
 */
contract MockStakedGEOToken is StakedGEOToken {
  /// @notice Exposes the ERC-7201 namespaced storage slot for `StakedGEOToken`
  function exposed__STAKED_GEO_TOKEN_STORAGE_LOCATION() external pure returns (bytes32 _stakedGEOTokenStorageLocation) {
    _stakedGEOTokenStorageLocation = _STAKED_GEO_TOKEN_STORAGE_LOCATION;
  }

  /// @notice Exposes `_findCheckpointAtOrBefore` for coverage of the empty-checkpoint path
  function exposed__findCheckpointAtOrBefore(
    address _account,
    uint256 _timepoint
  ) external view returns (uint32 _checkpointIndex) {
    _checkpointIndex = _findCheckpointAtOrBefore(_account, _timepoint);
  }

  /// @notice Exposes `_findStakeEligibleSince` for unit tests
  function exposed__findStakeEligibleSince(
    address _account,
    uint256 _timepoint
  ) external view returns (uint256 _sinceTimestamp) {
    _sinceTimestamp = _findStakeEligibleSince(_account, _timepoint);
  }

  /// @notice Mints balance and vote power to `_to` without calling public `mint`
  function workaround_mintBalance(address _to, uint256 _amount) external {
    _mint(_to, _amount);
  }

  /// @notice Burns balance and vote power from `_from` without calling public `burn`
  function workaround_burnBalance(address _from, uint256 _amount) external {
    _burn(_from, _amount);
  }

  /// @notice Seeds ERC20 allowance without calling public `approve`
  function workaround_seedAllowance(address _owner, address _spender, uint256 _amount) external {
    _approve(_owner, _spender, _amount);
  }
}
