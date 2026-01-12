// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {Test} from 'forge-std/Test.sol';

import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {DeployGEOBrowser} from 'script/DeployGEOBrowser.s.sol';

import {HandlerDAOSpace} from './handlers/HandlerDAOSpace.t.sol';
import {HandlerSpaceRegistry} from './handlers/HandlerSpaceRegistry.t.sol';
import {HandlerVerifierSpace} from './handlers/HandlerVerifierSpace.t.sol';

contract Setup is Test, DeployGEOBrowser {
  uint256 internal constant NUM_EOA_ACTORS = 3;
  uint256 internal constant NUM_DAO_SPACE_ACTORS = 2;
  uint256 internal constant NUM_VERIFIER_SPACE_ACTORS = 2;

  HandlerSpaceRegistry public handlerSpaceRegistry;
  HandlerDAOSpace public handlerDAOSpace;
  HandlerVerifierSpace public handlerVerifierSpace;

  address[] public eoaActors;
  address[] public daoSpaceActors;
  address[] public verifierSpaceActors;
  uint256[] public verifierSpaceOwnerKeys;

  IDAOSpace.VotingSettings internal _defaultVotingSettings;

  function setUp() public virtual override {
    DeployGEOBrowser.run();

    _initializeVotingSettings();
    _createEOAActors();
    _createDAOSpaceActors();
    _createVerifierSpaceActors();
    _configureTargets();
  }

  function _initializeVotingSettings() internal {
    // quorum and fastPathFlatThreshold must be <= totalEditors
    // Since we create DAOSpaces with 0 initial editors, these must be 0
    _defaultVotingSettings = IDAOSpace.VotingSettings({
      slowPathPercentageThreshold: 5e5, // 50%
      fastPathFlatThreshold: 0,
      quorum: 0,
      duration: 2 days
    });
  }

  function _createEOAActors() internal {
    eoaActors = new address[](NUM_EOA_ACTORS);
    for (uint256 i = 0; i < NUM_EOA_ACTORS; i++) {
      eoaActors[i] = makeAddr(string.concat('eoa', vm.toString(i)));
    }
  }

  function _createDAOSpaceActors() internal {
    // Initial editors must already be registered spaces, so we pass empty arrays
    daoSpaceActors = new address[](NUM_DAO_SPACE_ACTORS);
    for (uint256 i = 0; i < NUM_DAO_SPACE_ACTORS; i++) {
      daoSpaceActors[i] =
        daoSpaceFactoryProxy.createDAOSpaceProxy(_defaultVotingSettings, new bytes16[](0), new bytes16[](0), '', '');
    }
  }

  function _createVerifierSpaceActors() internal {
    verifierSpaceActors = new address[](NUM_VERIFIER_SPACE_ACTORS);
    verifierSpaceOwnerKeys = new uint256[](NUM_VERIFIER_SPACE_ACTORS);
    for (uint256 i = 0; i < NUM_VERIFIER_SPACE_ACTORS; i++) {
      (address spaceOwner, uint256 ownerKey) = makeAddrAndKey(string.concat('verifierSpaceOwner', vm.toString(i)));
      verifierSpaceOwnerKeys[i] = ownerKey;
      verifierSpaceActors[i] = verifierSpaceFactoryProxy.createVerifierSpaceProxy(spaceOwner);
    }
  }

  function _configureTargets() internal {
    for (uint256 i = 0; i < eoaActors.length; i++) {
      targetSender(eoaActors[i]);
    }

    handlerSpaceRegistry = new HandlerSpaceRegistry(spaceRegistryProxy, eoaActors, daoSpaceActors, verifierSpaceActors);
    handlerDAOSpace = new HandlerDAOSpace(spaceRegistryProxy, eoaActors, daoSpaceActors, verifierSpaceActors);
    handlerVerifierSpace = new HandlerVerifierSpace(
      spaceRegistryProxy, eoaActors, daoSpaceActors, verifierSpaceActors, verifierSpaceOwnerKeys
    );

    targetContract(address(handlerSpaceRegistry));
    targetContract(address(handlerDAOSpace));
    targetContract(address(handlerVerifierSpace));
  }
}
