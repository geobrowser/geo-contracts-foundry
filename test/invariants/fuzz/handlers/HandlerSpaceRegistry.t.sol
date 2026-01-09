// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {BaseHandler} from './BaseHandler.t.sol';
import {SpaceRegistry} from 'contracts/SpaceRegistry.sol';

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
    if (!isEOA(actor)) {
      lastTxSucceeded = false;
      return;
    }

    if (spaceRegistry.addressToSpaceId(actor) != bytes16(0)) {
      lastTxSucceeded = false;
      return;
    }

    vm.prank(actor);
    try spaceRegistry.registerSpaceId(bytes32(0), '') {
      bytes16 spaceId = spaceRegistry.addressToSpaceId(actor);
      if (!ghost_addressEverRegistered[actor]) {
        ghost_registeredAddresses.push(actor);
        ghost_addressEverRegistered[actor] = true;
      }
      ghost_isAddressRegistered[actor] = true;
      ghost_registeredSpaceIds.push(spaceId);
      ghost_isSpaceIdRegistered[spaceId] = true;

      ghost_totalRegistrations++;
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

    vm.prank(actor);
    try spaceRegistry.clearSpaceId() {
      ghost_isAddressRegistered[actor] = false;
      ghost_isSpaceIdRegistered[spaceId] = false;

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

    _actorSeed = bound(_actorSeed, 0, type(uint128).max);
    address newAccount;
    bool foundUnregistered = false;
    for (uint256 i = 0; i < eoaActors.length; i++) {
      uint256 idx = (_actorSeed + i) % eoaActors.length;
      address candidate = eoaActors[idx];
      if (spaceRegistry.addressToSpaceId(candidate) == bytes16(0) && candidate != actor) {
        newAccount = candidate;
        foundUnregistered = true;
        break;
      }
    }

    if (!foundUnregistered) {
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

    bytes16 targetSpaceId;
    address oldAddress;
    bool foundProposal = false;
    for (uint256 i = 0; i < ghost_registeredSpaceIds.length; i++) {
      bytes16 spaceId = ghost_registeredSpaceIds[i];
      if (ghost_isSpaceIdRegistered[spaceId]) {
        address proposedAddr = spaceRegistry.spaceIdToProposedAddress(spaceId);
        if (proposedAddr == actor) {
          targetSpaceId = spaceId;
          oldAddress = spaceRegistry.spaceIdToAddress(spaceId);
          foundProposal = true;
          break;
        }
      }
    }

    if (!foundProposal) {
      lastTxSucceeded = false;
      return;
    }

    vm.prank(actor);
    try spaceRegistry.acceptSpaceMigration(targetSpaceId, bytes32(0), '') {
      ghost_isAddressRegistered[oldAddress] = false;
      if (!ghost_addressEverRegistered[actor]) {
        ghost_registeredAddresses.push(actor);
        ghost_addressEverRegistered[actor] = true;
      }
      ghost_isAddressRegistered[actor] = true;
      ghost_migrations[oldAddress] = actor;
      ghost_acceptedMigrations++;

      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }
}
