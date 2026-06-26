// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Test} from 'forge-std/Test.sol';

import {StakingManager} from 'contracts/L2/StakingManager.sol';
import {StakingRegistry} from 'contracts/L2/StakingRegistry.sol';
import {L2GhostState} from 'test/invariants/L2/fuzz/handlers/L2GhostState.sol';
import {InvariantGEOToken} from 'test/invariants/L2/helpers/InvariantGEOToken.sol';

/// @notice Base contract for StakingManager invariant handlers
abstract contract L2BaseHandler is Test, L2GhostState {
  StakingManager public stakingManagerProxy;
  StakingRegistry public stakingRegistryProxy;
  InvariantGEOToken public geoToken;
  address public council;
  address[] public stakers;

  constructor(
    StakingManager _stakingManagerProxy,
    StakingRegistry _stakingRegistryProxy,
    InvariantGEOToken _geoToken,
    address _council,
    address[] memory _stakers
  ) {
    stakingManagerProxy = _stakingManagerProxy;
    stakingRegistryProxy = _stakingRegistryProxy;
    geoToken = _geoToken;
    council = _council;
    for (uint256 _i = 0; _i < _stakers.length; _i++) {
      stakers.push(_stakers[_i]);
    }
  }

  function _userTargetId(address _user, uint256 _seed) internal view returns (bytes32 _targetId) {
    uint256 _length = ghost_userTargetIdsLength(_user);
    if (_length == 0) return bytes32(0);
    _targetId = ghost_userTargetIdAt(_user, bound(_seed, 0, _length - 1));
  }
}
