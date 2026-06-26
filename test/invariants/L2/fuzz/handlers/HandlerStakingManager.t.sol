// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {StakingManager} from 'contracts/L2/StakingManager.sol';
import {StakingRegistry} from 'contracts/L2/StakingRegistry.sol';
import {IStakingManager} from 'interfaces/L2/IStakingManager.sol';
import {InvariantGEOToken} from 'test/invariants/L2/helpers/InvariantGEOToken.sol';

import {HandlerStakingRegistry} from 'test/invariants/L2/fuzz/handlers/HandlerStakingRegistry.t.sol';
import {L2BaseHandler} from 'test/invariants/L2/fuzz/handlers/L2BaseHandler.t.sol';

/// @notice Handler for user-facing `StakingManager` operations
contract HandlerStakingManager is L2BaseHandler {
  uint256 internal constant _MAX_STAKE_AMOUNT = type(uint208).max;

  HandlerStakingRegistry public registryHandler;

  bool public lastTxSucceeded;

  constructor(
    StakingManager _stakingManagerProxy,
    StakingRegistry _stakingRegistryProxy,
    InvariantGEOToken _geoToken,
    address _council,
    address[] memory _stakers,
    HandlerStakingRegistry _registryHandler
  ) L2BaseHandler(_stakingManagerProxy, _stakingRegistryProxy, _geoToken, _council, _stakers) {
    registryHandler = _registryHandler;
  }

  /// @notice Transfers GEO to the manager outside `stake` (unsolicited custody)
  function handler_transferGeoToManager(uint256 _amount) external {
    address _donor = msg.sender;
    uint256 _transferAmount = bound(_amount, 1, _MAX_STAKE_AMOUNT);

    deal(address(geoToken), _donor, _transferAmount);
    vm.prank(_donor);
    try geoToken.transfer(address(stakingManagerProxy), _transferAmount) {
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_stake(uint256 _amount) external {
    address _user = msg.sender;
    uint256 _minAmount = stakingManagerProxy.minAmount();
    uint256 _stakeAmount = bound(_amount, _minAmount, _MAX_STAKE_AMOUNT);

    deal(address(geoToken), _user, _stakeAmount);
    vm.prank(_user);
    try geoToken.approve(address(stakingManagerProxy), _stakeAmount) {}
    catch {
      lastTxSucceeded = false;
      return;
    }
    vm.prank(_user);
    try stakingManagerProxy.stake(_stakeAmount) {
      _ghostTrackUser(_user);
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_stakeFor(uint256 _recipientSeed, uint256 _amount) external {
    address _staker = msg.sender;
    address _recipient = stakers[bound(_recipientSeed, 0, stakers.length - 1)];
    uint256 _minAmount = stakingManagerProxy.minAmount();
    uint256 _stakeAmount = bound(_amount, _minAmount, _MAX_STAKE_AMOUNT);

    deal(address(geoToken), _staker, _stakeAmount);
    vm.prank(_staker);
    try geoToken.approve(address(stakingManagerProxy), _stakeAmount) {}
    catch {
      lastTxSucceeded = false;
      return;
    }
    vm.prank(_staker);
    try stakingManagerProxy.stakeFor(_recipient, _stakeAmount) {
      _ghostTrackUser(_recipient);
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_requestUnstake(uint256 _amount) external {
    address _user = msg.sender;
    uint256 _minAmount = stakingManagerProxy.minAmount();
    uint256 _disposable = stakingManagerProxy.totalUserDisposableStake(_user);
    if (_disposable == 0) {
      lastTxSucceeded = false;
      return;
    }

    uint256 _requestAmount = bound(_amount, 1, _disposable);
    if (_requestAmount < _minAmount && _requestAmount != _disposable) {
      lastTxSucceeded = false;
      return;
    }
    uint256 _remainder = _disposable - _requestAmount;
    if (_remainder != 0 && _remainder < _minAmount) {
      lastTxSucceeded = false;
      return;
    }

    vm.prank(_user);
    try stakingManagerProxy.requestUnstake(_requestAmount) returns (uint256 _unstakeId) {
      _ghostTrackUser(_user);
      _ghostTrackOpenUnstake(_unstakeId);
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_unstake(uint256 _unstakeSeed) external {
    address _user = msg.sender;
    uint256 _length = ghost_openUnstakeIdsLength();
    if (_length == 0) {
      lastTxSucceeded = false;
      return;
    }

    uint256 _baseIndex = bound(_unstakeSeed, 0, _length - 1);
    for (uint256 _attempt = 0; _attempt < _length; _attempt++) {
      uint256 _index = (_baseIndex + _attempt) % _length;
      uint256 _unstakeId = ghost_openUnstakeIdAt(_index);
      if (!ghost_isOpenUnstake(_unstakeId)) continue;

      IStakingManager.UnstakeRequest memory _request = stakingManagerProxy.unstakeRequests(_unstakeId);
      if (_request.user == address(0) || _request.user != _user || vm.getBlockTimestamp() < _request.unlockTime) {
        continue;
      }

      vm.prank(_user);
      try stakingManagerProxy.unstake(_unstakeId) {
        _ghostCloseUnstake(_unstakeId);
        lastTxSucceeded = true;
        return;
      } catch {
        continue;
      }
    }

    lastTxSucceeded = false;
  }

  function handler_allocate(uint256 _targetSeed, uint256 _amount) external {
    address _user = msg.sender;
    bytes32 _targetId = _activeTargetId(_targetSeed);
    if (_targetId == bytes32(0)) {
      lastTxSucceeded = false;
      return;
    }

    uint256 _minAmount = stakingManagerProxy.minAmount();
    uint256 _disposable = stakingManagerProxy.totalUserDisposableStake(_user);
    if (_disposable < _minAmount) {
      lastTxSucceeded = false;
      return;
    }

    uint256 _allocAmount = bound(_amount, _minAmount, _disposable);

    vm.prank(_user);
    try stakingManagerProxy.allocate(_targetId, _allocAmount) {
      _ghostTrackUser(_user);
      _ghostTrackUserTarget(_user, _targetId);
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_deallocate(uint256 _targetSeed, uint256 _amount) external {
    address _user = msg.sender;
    bytes32 _targetId = _userTargetId(_user, _targetSeed);
    if (_targetId == bytes32(0)) {
      lastTxSucceeded = false;
      return;
    }

    uint256 _allocated = stakingManagerProxy.allocations(_user, _targetId);
    if (_allocated == 0) {
      lastTxSucceeded = false;
      return;
    }

    uint256 _minAmount = stakingManagerProxy.minAmount();
    uint256 _deallocAmount = bound(_amount, 1, _allocated);
    if (_deallocAmount < _minAmount && _deallocAmount != _allocated) {
      lastTxSucceeded = false;
      return;
    }
    uint256 _remainder = _allocated - _deallocAmount;
    if (_remainder != 0 && _remainder < _minAmount) {
      lastTxSucceeded = false;
      return;
    }

    vm.prank(_user);
    try stakingManagerProxy.deallocate(_targetId, _deallocAmount) {
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_reallocate(uint256 _fromTargetSeed, uint256 _toTargetSeed, uint256 _amount) external {
    address _user = msg.sender;
    bytes32 _fromTargetId = _userTargetId(_user, _fromTargetSeed);
    bytes32 _toTargetId = _activeTargetId(_toTargetSeed);
    if (_fromTargetId == bytes32(0) || _toTargetId == bytes32(0) || _fromTargetId == _toTargetId) {
      lastTxSucceeded = false;
      return;
    }

    uint256 _allocatedFrom = stakingManagerProxy.allocations(_user, _fromTargetId);
    uint256 _minAmount = stakingManagerProxy.minAmount();
    if (_allocatedFrom < _minAmount) {
      lastTxSucceeded = false;
      return;
    }

    uint256 _reallocAmount = bound(_amount, _minAmount, _allocatedFrom);
    uint256 _remainderOnSource = _allocatedFrom - _reallocAmount;
    if (_remainderOnSource != 0 && _remainderOnSource < _minAmount) {
      lastTxSucceeded = false;
      return;
    }

    uint256 _totalAllocatedBefore = stakingManagerProxy.totalAllocated();
    uint256 _userAllocationBefore = stakingManagerProxy.totalUserAllocation(_user);

    vm.prank(_user);
    try stakingManagerProxy.reallocate(_fromTargetId, _toTargetId, _reallocAmount) {
      if (stakingManagerProxy.totalAllocated() != _totalAllocatedBefore) {
        _ghostMarkReallocateTotalAllocatedViolation();
      }
      if (stakingManagerProxy.totalUserAllocation(_user) != _userAllocationBefore) {
        _ghostMarkReallocateUserAllocationViolation(_user);
      }
      _ghostTrackUserTarget(_user, _toTargetId);
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function _activeTargetId(uint256 _seed) internal view returns (bytes32 _targetId) {
    uint256 _length = registryHandler.ghost_activeTargetIdsLength();
    if (_length == 0) return bytes32(0);
    _targetId = registryHandler.ghost_activeTargetIds(bound(_seed, 0, _length - 1));
  }
}
