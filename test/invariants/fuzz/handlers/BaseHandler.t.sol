// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {GhostState} from './GhostState.sol';
import {SpaceRegistry} from 'contracts/SpaceRegistry.sol';
import {Test} from 'forge-std/Test.sol';

/// @notice Base contract for all handlers
abstract contract BaseHandler is Test, GhostState {
  SpaceRegistry public spaceRegistry;

  // Different actor types
  address[] public eoaActors;
  address[] public daoSpaceActors;
  address[] public verifierSpaceActors;

  constructor(
    SpaceRegistry _spaceRegistry,
    address[] memory _eoaActors,
    address[] memory _daoSpaceActors,
    address[] memory _verifierSpaceActors
  ) {
    spaceRegistry = _spaceRegistry;

    for (uint256 i = 0; i < _eoaActors.length; i++) {
      eoaActors.push(_eoaActors[i]);
      ghost_actorType[_eoaActors[i]] = ActorType.EOA;
    }

    for (uint256 i = 0; i < _daoSpaceActors.length; i++) {
      daoSpaceActors.push(_daoSpaceActors[i]);
      ghost_actorType[_daoSpaceActors[i]] = ActorType.DAOSpace;
      _trackPreRegisteredSpace(_daoSpaceActors[i]);
    }

    for (uint256 i = 0; i < _verifierSpaceActors.length; i++) {
      verifierSpaceActors.push(_verifierSpaceActors[i]);
      ghost_actorType[_verifierSpaceActors[i]] = ActorType.VerifierSpace;
      _trackPreRegisteredSpace(_verifierSpaceActors[i]);
    }
  }

  function _trackPreRegisteredSpace(address _space) internal {
    bytes16 spaceId = spaceRegistry.addressToSpaceId(_space);
    require(spaceId != bytes16(0), 'Space not registered');

    ghost_registeredAddresses.push(_space);
    ghost_addressEverRegistered[_space] = true;
    ghost_isAddressRegistered[_space] = true;

    ghost_registeredSpaceIds.push(spaceId);
    ghost_isSpaceIdRegistered[spaceId] = true;

    ghost_factoryCreatedSpaces++;
    ghost_factoryCreatedSpaceAddresses.push(_space);
  }

  function isEOA(address _addr) public view returns (bool) {
    return ghost_actorType[_addr] == ActorType.EOA;
  }

  function isDAOSpace(address _addr) public view returns (bool) {
    return ghost_actorType[_addr] == ActorType.DAOSpace;
  }

  function isVerifierSpace(address _addr) public view returns (bool) {
    return ghost_actorType[_addr] == ActorType.VerifierSpace;
  }

  function isSpaceContract(address _addr) public view returns (bool) {
    return isDAOSpace(_addr) || isVerifierSpace(_addr);
  }

  function handler_warp(uint256 _delta) public {
    _delta = bound(_delta, 0, 365 days);
    vm.warp(block.timestamp + _delta);
  }

  function handler_roll(uint256 _delta) public {
    _delta = bound(_delta, 0, 1_000_000);
    vm.roll(block.number + _delta);
  }
}
