// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {SpaceRegistry} from 'contracts/SpaceRegistry.sol';

import {BaseHandler} from 'test/invariants/fuzz/handlers/BaseHandler.t.sol';

/// @notice Handler for SpaceRegistry operations
contract HandlerSpaceRegistry is BaseHandler {
  bool public lastTxSucceeded;

  constructor(
    SpaceRegistry _spaceRegistry,
    address[] memory _eoaActors,
    address[] memory _daoSpaceActors,
    address[] memory _verifierSpaceActors
  ) BaseHandler(_spaceRegistry, _eoaActors, _daoSpaceActors, _verifierSpaceActors) {}

  function handler_registerSpaceId() external {
    address _actor = msg.sender;
    if (!isEOA(_actor) || spaceRegistry.addressToSpaceId(_actor) != bytes16(0)) {
      lastTxSucceeded = false;
      return;
    }

    vm.prank(_actor);
    try spaceRegistry.registerSpaceId(bytes32(0), '') {
      bytes16 _spaceId = spaceRegistry.addressToSpaceId(_actor);
      _trackNewRegistration(_actor, _spaceId);
      ghost_totalRegistrations++;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_archiveSpaceId() external {
    address _actor = msg.sender;
    bytes16 _spaceId = spaceRegistry.addressToSpaceId(_actor);
    if (_spaceId == bytes16(0)) {
      lastTxSucceeded = false;
      return;
    }

    // Check if already archived
    if (spaceRegistry.archivedSpaceIds(_spaceId)) {
      lastTxSucceeded = false;
      return;
    }

    vm.prank(_actor);
    try spaceRegistry.archiveSpaceId() {
      // Space is still registered, just archived
      ghost_isSpaceIdArchived[_spaceId] = true;
      ghost_totalArchives++;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_recoverSpaceId() external {
    address _actor = msg.sender;
    bytes16 _spaceId = spaceRegistry.addressToSpaceId(_actor);
    if (_spaceId == bytes16(0)) {
      lastTxSucceeded = false;
      return;
    }

    // Check if archived
    if (!spaceRegistry.archivedSpaceIds(_spaceId)) {
      lastTxSucceeded = false;
      return;
    }

    vm.prank(_actor);
    try spaceRegistry.recoverSpaceId() {
      // Space is still registered, just un-archived
      ghost_isSpaceIdArchived[_spaceId] = false;
      ghost_totalRecoveries++;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_clearSpaceId() external {
    address _actor = msg.sender;
    bytes16 _spaceId = spaceRegistry.addressToSpaceId(_actor);
    if (_spaceId == bytes16(0)) {
      lastTxSucceeded = false;
      return;
    }

    // Must be archived before clearing
    if (!spaceRegistry.archivedSpaceIds(_spaceId)) {
      lastTxSucceeded = false;
      return;
    }

    vm.prank(_actor);
    try spaceRegistry.clearSpaceId() {
      ghost_isAddressRegistered[_actor] = false;
      ghost_isSpaceIdRegistered[_spaceId] = false;
      ghost_isSpaceIdArchived[_spaceId] = false;
      ghost_totalClears++;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_proposeSpaceMigration(uint256 _actorSeed) external {
    address _actor = msg.sender;
    bytes16 _spaceId = spaceRegistry.addressToSpaceId(_actor);
    if (_spaceId == bytes16(0)) {
      lastTxSucceeded = false;
      return;
    }

    // Cannot propose migration if archived
    if (spaceRegistry.archivedSpaceIds(_spaceId)) {
      lastTxSucceeded = false;
      return;
    }

    address _newAccount = _findUnregisteredEOA(_actorSeed, _actor);
    if (_newAccount == address(0)) {
      lastTxSucceeded = false;
      return;
    }

    vm.prank(_actor);
    try spaceRegistry.proposeSpaceMigration(_newAccount) {
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_acceptSpaceMigration() external {
    address _actor = msg.sender;
    if (spaceRegistry.addressToSpaceId(_actor) != bytes16(0)) {
      lastTxSucceeded = false;
      return;
    }

    (bytes16 _targetSpaceId, address _oldAddress, bool _found) = _findPendingMigration(_actor);
    if (!_found) {
      lastTxSucceeded = false;
      return;
    }

    // Cannot accept migration if source space is archived
    if (spaceRegistry.archivedSpaceIds(_targetSpaceId)) {
      lastTxSucceeded = false;
      return;
    }

    vm.prank(_actor);
    try spaceRegistry.acceptSpaceMigration(_targetSpaceId, bytes32(0), '') {
      ghost_isAddressRegistered[_oldAddress] = false;
      _trackNewRegistration(_actor, _targetSpaceId);
      // Space is not archived after migration (check prevents archived spaces from migrating)
      ghost_isSpaceIdArchived[_targetSpaceId] = false;
      ghost_migrations[_oldAddress] = _actor;
      ghost_acceptedMigrations++;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function _trackNewRegistration(address _addr, bytes16 _spaceId) internal {
    if (!ghost_addressEverRegistered[_addr]) {
      ghost_registeredAddresses.push(_addr);
      ghost_addressEverRegistered[_addr] = true;
    }
    ghost_isAddressRegistered[_addr] = true;
    ghost_registeredSpaceIds.push(_spaceId);
    ghost_isSpaceIdRegistered[_spaceId] = true;
    ghost_isSpaceIdArchived[_spaceId] = false;
  }

  function _findUnregisteredEOA(uint256 _seed, address _exclude) internal view returns (address _unregisteredEOA) {
    _seed = bound(_seed, 0, type(uint128).max);
    for (uint256 _i = 0; _i < eoaActors.length; _i++) {
      uint256 _idx = (_seed + _i) % eoaActors.length;
      address _candidate = eoaActors[_idx];
      if (spaceRegistry.addressToSpaceId(_candidate) == bytes16(0) && _candidate != _exclude) {
        return _candidate;
      }
    }
    return address(0);
  }

  function _findPendingMigration(address _proposedAddr)
    internal
    view
    returns (bytes16 _spaceId, address _oldAddress, bool _found)
  {
    for (uint256 _i = 0; _i < ghost_registeredSpaceIds.length; _i++) {
      bytes16 _id = ghost_registeredSpaceIds[_i];
      if (ghost_isSpaceIdRegistered[_id] && spaceRegistry.spaceIdToProposedAddress(_id) == _proposedAddr) {
        return (_id, spaceRegistry.spaceIdToAddress(_id), true);
      }
    }
    return (bytes16(0), address(0), false);
  }
}
