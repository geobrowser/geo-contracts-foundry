// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {StakingManager} from 'contracts/L2/StakingManager.sol';
import {StakingRegistry} from 'contracts/L2/StakingRegistry.sol';
import {IStakingRegistry} from 'interfaces/L2/IStakingRegistry.sol';
import {InvariantGEOToken} from 'test/invariants/L2/helpers/InvariantGEOToken.sol';

import {L2BaseHandler} from 'test/invariants/L2/fuzz/handlers/L2BaseHandler.t.sol';

/// @notice Handler for council `StakingRegistry` operations
contract HandlerStakingRegistry is L2BaseHandler {
  uint256 public constant PRESEED_TARGET_COUNT = 3;
  uint256 public constant PRESEED_TARGET_A_INDEX = 0;
  uint256 public constant PRESEED_TARGET_B_INDEX = 1;
  uint256 public constant PRESEED_TARGET_C_INDEX = 2;

  bytes32 public constant PRESEED_TARGET_A = keccak256('invariant_target_a');
  bytes32 public constant PRESEED_TARGET_B = keccak256('invariant_target_b');
  bytes32 public constant PRESEED_TARGET_C = keccak256('invariant_target_c');

  bool public lastTxSucceeded;

  constructor(
    StakingManager _stakingManagerProxy,
    StakingRegistry _stakingRegistryProxy,
    InvariantGEOToken _geoToken,
    address _council,
    address[] memory _stakers
  ) L2BaseHandler(_stakingManagerProxy, _stakingRegistryProxy, _geoToken, _council, _stakers) {
    bytes32[PRESEED_TARGET_COUNT] memory _targetIds = [PRESEED_TARGET_A, PRESEED_TARGET_B, PRESEED_TARGET_C];
    IStakingRegistry.Target memory _activeTarget =
      IStakingRegistry.Target({tType: IStakingRegistry.TargetType.Space, tActive: true});

    vm.startPrank(_council);
    for (uint256 _i = 0; _i < _targetIds.length; _i++) {
      stakingRegistryProxy.setTarget(_targetIds[_i], _activeTarget);
      _ghostTrackActiveTarget(_targetIds[_i]);
    }
    vm.stopPrank();
  }

  function handler_setTargetActive(uint256 _targetSeed, bool _active) external {
    bytes32 _targetId = bytes32(bound(_targetSeed, 1, type(uint256).max));
    IStakingRegistry.Target memory _target =
      IStakingRegistry.Target({tType: IStakingRegistry.TargetType.Space, tActive: _active});

    vm.prank(council);
    try stakingRegistryProxy.setTarget(_targetId, _target) {
      if (_active) {
        _ghostTrackActiveTarget(_targetId);
      } else {
        _ghostDeactivateTarget(_targetId);
      }
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }
}
