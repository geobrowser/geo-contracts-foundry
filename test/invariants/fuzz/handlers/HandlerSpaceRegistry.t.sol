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
    address actor = msg.sender;
    if (!isEOA(actor) || spaceRegistry.addressToSpaceId(actor) != bytes16(0)) {
      lastTxSucceeded = false;
      return;
    }

    vm.prank(actor);
    try spaceRegistry.registerSpaceId(bytes32(0), '') {
      bytes16 spaceId = spaceRegistry.addressToSpaceId(actor);
      _trackNewRegistration(actor, spaceId);
      ghost_totalRegistrations++;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_archiveSpaceId() external {
    address actor = msg.sender;
    bytes16 spaceId = spaceRegistry.addressToSpaceId(actor);
    if (spaceId == bytes16(0)) {
      lastTxSucceeded = false;
      return;
    }

    // Check if already archived
    if (spaceRegistry.archivedSpaceIds(spaceId)) {
      lastTxSucceeded = false;
      return;
    }

    vm.prank(actor);
    try spaceRegistry.archiveSpaceId() {
      // Space is still registered, just archived
      ghost_isSpaceIdArchived[spaceId] = true;
      ghost_totalArchives++;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_recoverSpaceId() external {
    address actor = msg.sender;
    bytes16 spaceId = spaceRegistry.addressToSpaceId(actor);
    if (spaceId == bytes16(0)) {
      lastTxSucceeded = false;
      return;
    }

    // Check if archived
    if (!spaceRegistry.archivedSpaceIds(spaceId)) {
      lastTxSucceeded = false;
      return;
    }

    vm.prank(actor);
    try spaceRegistry.recoverSpaceId() {
      // Space is still registered, just un-archived
      ghost_isSpaceIdArchived[spaceId] = false;
      ghost_totalRecoveries++;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_clearSpaceId() external {
    address actor = msg.sender;
    bytes16 spaceId = spaceRegistry.addressToSpaceId(actor);
    if (spaceId == bytes16(0)) {
      lastTxSucceeded = false;
      return;
    }

    // Must be archived before clearing
    if (!spaceRegistry.archivedSpaceIds(spaceId)) {
      lastTxSucceeded = false;
      return;
    }

    vm.prank(actor);
    try spaceRegistry.clearSpaceId() {
      ghost_isAddressRegistered[actor] = false;
      ghost_isSpaceIdRegistered[spaceId] = false;
      ghost_isSpaceIdArchived[spaceId] = false;
      ghost_totalClears++;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_proposeSpaceMigration(uint256 _actorSeed) external {
    address actor = msg.sender;
    bytes16 spaceId = spaceRegistry.addressToSpaceId(actor);
    if (spaceId == bytes16(0)) {
      lastTxSucceeded = false;
      return;
    }

    // Cannot propose migration if archived
    if (spaceRegistry.archivedSpaceIds(spaceId)) {
      lastTxSucceeded = false;
      return;
    }

    address newAccount = _findUnregisteredEOA(_actorSeed, actor);
    if (newAccount == address(0)) {
      lastTxSucceeded = false;
      return;
    }

    vm.prank(actor);
    try spaceRegistry.proposeSpaceMigration(newAccount) {
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_acceptSpaceMigration() external {
    address actor = msg.sender;
    if (spaceRegistry.addressToSpaceId(actor) != bytes16(0)) {
      lastTxSucceeded = false;
      return;
    }

    (bytes16 targetSpaceId, address oldAddress, bool found) = _findPendingMigration(actor);
    if (!found) {
      lastTxSucceeded = false;
      return;
    }

    // Cannot accept migration if source space is archived
    if (spaceRegistry.archivedSpaceIds(targetSpaceId)) {
      lastTxSucceeded = false;
      return;
    }

    vm.prank(actor);
    try spaceRegistry.acceptSpaceMigration(targetSpaceId, bytes32(0), '') {
      ghost_isAddressRegistered[oldAddress] = false;
      _trackNewRegistration(actor, targetSpaceId);
      // Space is not archived after migration (check prevents archived spaces from migrating)
      ghost_isSpaceIdArchived[targetSpaceId] = false;
      ghost_migrations[oldAddress] = actor;
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
    for (uint256 i = 0; i < eoaActors.length; i++) {
      uint256 idx = (_seed + i) % eoaActors.length;
      address candidate = eoaActors[idx];
      if (spaceRegistry.addressToSpaceId(candidate) == bytes16(0) && candidate != _exclude) {
        return candidate;
      }
    }
    return address(0);
  }

  function _findPendingMigration(address _proposedAddr)
    internal
    view
    returns (bytes16 _spaceId, address _oldAddress, bool _found)
  {
    for (uint256 i = 0; i < ghost_registeredSpaceIds.length; i++) {
      bytes16 id = ghost_registeredSpaceIds[i];
      if (ghost_isSpaceIdRegistered[id] && spaceRegistry.spaceIdToProposedAddress(id) == _proposedAddr) {
        return (id, spaceRegistry.spaceIdToAddress(id), true);
      }
    }
    return (bytes16(0), address(0), false);
  }
}
