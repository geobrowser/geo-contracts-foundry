// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Test} from 'forge-std/Test.sol';

import {SpaceRegistry} from 'contracts/SpaceRegistry.sol';

import {GhostState} from 'test/invariants/fuzz/handlers/GhostState.sol';

/// @notice Base contract for all handlers
abstract contract BaseHandler is Test, GhostState {
  SpaceRegistry public spaceRegistry;
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
    _initializeActors(_eoaActors, _daoSpaceActors, _verifierSpaceActors);
  }

  function _initializeActors(
    address[] memory _eoaActors,
    address[] memory _daoSpaceActors,
    address[] memory _verifierSpaceActors
  ) internal {
    for (uint256 _i = 0; _i < _eoaActors.length; _i++) {
      eoaActors.push(_eoaActors[_i]);
      ghost_actorType[_eoaActors[_i]] = ActorType.EOA;
    }

    for (uint256 _i = 0; _i < _daoSpaceActors.length; _i++) {
      daoSpaceActors.push(_daoSpaceActors[_i]);
      ghost_actorType[_daoSpaceActors[_i]] = ActorType.DAOSpace;
      _trackPreRegisteredSpace(_daoSpaceActors[_i]);
    }

    for (uint256 _i = 0; _i < _verifierSpaceActors.length; _i++) {
      verifierSpaceActors.push(_verifierSpaceActors[_i]);
      ghost_actorType[_verifierSpaceActors[_i]] = ActorType.VerifierSpace;
      _trackPreRegisteredSpace(_verifierSpaceActors[_i]);
    }
  }

  function _trackPreRegisteredSpace(address _space) internal {
    bytes16 _spaceId = spaceRegistry.addressToSpaceId(_space);
    require(_spaceId != bytes16(0), 'Space not registered');

    ghost_registeredAddresses.push(_space);
    ghost_addressEverRegistered[_space] = true;
    ghost_isAddressRegistered[_space] = true;
    ghost_registeredSpaceIds.push(_spaceId);
    ghost_isSpaceIdRegistered[_spaceId] = true;
    ghost_isSpaceIdArchived[_spaceId] = false;
    ghost_factoryCreatedSpaces++;
    ghost_factoryCreatedSpaceAddresses.push(_space);
  }

  function isEOA(address _addr) public view returns (bool _isEOA) {
    return ghost_actorType[_addr] == ActorType.EOA;
  }

  function isDAOSpace(address _addr) public view returns (bool _isDAOSpace) {
    return ghost_actorType[_addr] == ActorType.DAOSpace;
  }

  function isVerifierSpace(address _addr) public view returns (bool _isVerifierSpace) {
    return ghost_actorType[_addr] == ActorType.VerifierSpace;
  }

  function isSpaceContract(address _addr) public view returns (bool _isSpaceContract) {
    return isDAOSpace(_addr) || isVerifierSpace(_addr);
  }
}
