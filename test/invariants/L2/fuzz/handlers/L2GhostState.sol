// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

/// @notice Tracked address set for closed-world invariant iteration
struct GhostAddressSet {
  address[] items;
  mapping(address => bool) isMember;
}

/// @notice Tracked bytes32 id set for closed-world invariant iteration
struct GhostBytes32Set {
  bytes32[] items;
  mapping(bytes32 => bool) isMember;
}

/// @notice Tracked open unstake request ids
struct GhostUnstakeSet {
  uint256[] openIds;
  mapping(uint256 => bool) isOpen;
}

/// @notice Bidirectional user ↔ target allocation links
struct GhostAllocationGraph {
  GhostBytes32Set targets;
  mapping(address => bytes32[]) userTargetIds;
  mapping(address => mapping(bytes32 => bool)) userHasTarget;
  mapping(bytes32 => address[]) targetUsers;
  mapping(bytes32 => mapping(address => bool)) targetHasUser;
}

/// @notice Flags set when `reallocate` mutates aggregate totals unexpectedly
struct GhostReallocateChecks {
  bool violatedTotalAllocated;
  mapping(address => bool) violatedUserAllocation;
}

/// @notice Ghost state for StakingManager invariant testing
abstract contract L2GhostState {
  GhostAddressSet private _ghost_users;
  GhostBytes32Set private _ghost_activeTargets;
  GhostAllocationGraph private _ghost_allocations;
  GhostUnstakeSet private _ghost_unstakes;
  GhostReallocateChecks private _ghost_reallocate;

  // ==================== View functions ====================

  function ghost_users(uint256 _index) public view returns (address _user) {
    return _ghost_users.items[_index];
  }

  function ghost_usersLength() public view returns (uint256 _length) {
    return _ghost_users.items.length;
  }

  function ghost_isUser(address _user) public view returns (bool _isUser) {
    return _ghost_users.isMember[_user];
  }

  function ghost_activeTargetIds(uint256 _index) public view returns (bytes32 _targetId) {
    return _ghost_activeTargets.items[_index];
  }

  function ghost_activeTargetIdsLength() public view returns (uint256 _length) {
    return _ghost_activeTargets.items.length;
  }

  function ghost_isActiveTarget(bytes32 _targetId) public view returns (bool _isActive) {
    return _ghost_activeTargets.isMember[_targetId];
  }

  function ghost_allocatedTargetIds(uint256 _index) public view returns (bytes32 _targetId) {
    return _ghost_allocations.targets.items[_index];
  }

  function ghost_allocatedTargetIdsLength() public view returns (uint256 _length) {
    return _ghost_allocations.targets.items.length;
  }

  function ghost_isAllocatedTarget(bytes32 _targetId) public view returns (bool _isAllocated) {
    return _ghost_allocations.targets.isMember[_targetId];
  }

  function ghost_userTargetIdsLength(address _user) public view returns (uint256 _length) {
    return _ghost_allocations.userTargetIds[_user].length;
  }

  function ghost_userTargetIdAt(address _user, uint256 _index) public view returns (bytes32 _targetId) {
    return _ghost_allocations.userTargetIds[_user][_index];
  }

  function ghost_userHasTarget(address _user, bytes32 _targetId) public view returns (bool _hasTarget) {
    return _ghost_allocations.userHasTarget[_user][_targetId];
  }

  function ghost_targetUsersLength(bytes32 _targetId) public view returns (uint256 _length) {
    return _ghost_allocations.targetUsers[_targetId].length;
  }

  function ghost_targetUserAt(bytes32 _targetId, uint256 _index) public view returns (address _user) {
    return _ghost_allocations.targetUsers[_targetId][_index];
  }

  function ghost_targetHasUser(bytes32 _targetId, address _user) public view returns (bool _hasUser) {
    return _ghost_allocations.targetHasUser[_targetId][_user];
  }

  function ghost_openUnstakeIdsLength() public view returns (uint256 _length) {
    return _ghost_unstakes.openIds.length;
  }

  function ghost_openUnstakeIdAt(uint256 _index) public view returns (uint256 _unstakeId) {
    return _ghost_unstakes.openIds[_index];
  }

  function ghost_isOpenUnstake(uint256 _unstakeId) public view returns (bool _isOpen) {
    return _ghost_unstakes.isOpen[_unstakeId];
  }

  function ghost_reallocateViolatedTotalAllocated() public view returns (bool _violated) {
    return _ghost_reallocate.violatedTotalAllocated;
  }

  function ghost_reallocateViolatedUserAllocation(address _user) public view returns (bool _violated) {
    return _ghost_reallocate.violatedUserAllocation[_user];
  }

  function _ghostTrackUser(address _user) internal {
    _ghostAddAddress(_ghost_users, _user);
  }

  function _ghostTrackUserTarget(address _user, bytes32 _targetId) internal {
    if (!_ghost_allocations.userHasTarget[_user][_targetId]) {
      _ghost_allocations.userHasTarget[_user][_targetId] = true;
      _ghost_allocations.userTargetIds[_user].push(_targetId);
    }
    if (!_ghost_allocations.targetHasUser[_targetId][_user]) {
      _ghost_allocations.targetHasUser[_targetId][_user] = true;
      _ghost_allocations.targetUsers[_targetId].push(_user);
    }
    _ghostAddBytes32(_ghost_allocations.targets, _targetId);
  }

  function _ghostTrackActiveTarget(bytes32 _targetId) internal {
    _ghostAddBytes32(_ghost_activeTargets, _targetId);
  }

  function _ghostDeactivateTarget(bytes32 _targetId) internal {
    _ghostRemoveBytes32(_ghost_activeTargets, _targetId);
  }

  function _ghostTrackOpenUnstake(uint256 _unstakeId) internal {
    if (_ghost_unstakes.isOpen[_unstakeId]) return;
    _ghost_unstakes.isOpen[_unstakeId] = true;
    _ghost_unstakes.openIds.push(_unstakeId);
  }

  function _ghostCloseUnstake(uint256 _unstakeId) internal {
    if (!_ghost_unstakes.isOpen[_unstakeId]) return;
    _ghost_unstakes.isOpen[_unstakeId] = false;
    _ghostRemoveFromUint256Array(_ghost_unstakes.openIds, _unstakeId);
  }

  function _ghostMarkReallocateTotalAllocatedViolation() internal {
    _ghost_reallocate.violatedTotalAllocated = true;
  }

  function _ghostMarkReallocateUserAllocationViolation(address _user) internal {
    _ghost_reallocate.violatedUserAllocation[_user] = true;
  }

  function _ghostAddAddress(GhostAddressSet storage _set, address _item) internal {
    if (_set.isMember[_item]) return;
    _set.isMember[_item] = true;
    _set.items.push(_item);
  }

  function _ghostAddBytes32(GhostBytes32Set storage _set, bytes32 _item) internal {
    if (_set.isMember[_item]) return;
    _set.isMember[_item] = true;
    _set.items.push(_item);
  }

  function _ghostRemoveBytes32(GhostBytes32Set storage _set, bytes32 _item) internal {
    if (!_set.isMember[_item]) return;
    _set.isMember[_item] = false;
    _ghostRemoveFromBytes32Array(_set.items, _item);
  }

  function _ghostRemoveFromBytes32Array(bytes32[] storage _items, bytes32 _item) internal {
    uint256 _length = _items.length;
    for (uint256 _i = 0; _i < _length; _i++) {
      if (_items[_i] == _item) {
        _items[_i] = _items[_length - 1];
        _items.pop();
        break;
      }
    }
  }

  function _ghostRemoveFromUint256Array(uint256[] storage _items, uint256 _item) internal {
    uint256 _length = _items.length;
    for (uint256 _i = 0; _i < _length; _i++) {
      if (_items[_i] == _item) {
        _items[_i] = _items[_length - 1];
        _items.pop();
        break;
      }
    }
  }
}
