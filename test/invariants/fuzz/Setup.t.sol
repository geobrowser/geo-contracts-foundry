// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from 'forge-std/Test.sol';

import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {DeployGEOBrowser} from 'script/DeployGEOBrowser.s.sol';

import {HandlerDAOSpace} from './handlers/HandlerDAOSpace.t.sol';
import {HandlerSpaceRegistry} from './handlers/HandlerSpaceRegistry.t.sol';
import {HandlerVerifierSpace} from './handlers/HandlerVerifierSpace.t.sol';

contract Setup is Test, DeployGEOBrowser {
  // Handlers
  HandlerSpaceRegistry public handlerSpaceRegistry;
  HandlerDAOSpace public handlerDAOSpace;
  HandlerVerifierSpace public handlerVerifierSpace;

  // EOA actors (can call registerSpaceId directly)
  address[] public eoaActors;

  // Space contract actors (DAOSpace and VerifierSpace instances)
  address[] public daoSpaceActors;
  address[] public verifierSpaceActors;

  // VerifierSpace owner private keys (for signing)
  uint256[] public verifierSpaceOwnerKeys;

  // Voting settings for DAOSpace creation
  IDAOSpace.VotingSettings internal defaultVotingSettings;

  function setUp() public virtual override {
    // Deploy protocol using the deploy script (no broadcast needed in tests)
    DeployGEOBrowser.run();

    // Default voting settings for DAOSpace
    // Note: quorum and fastPathFlatThreshold must be <= totalEditors
    // Since we create DAOSpaces with 0 initial editors, these must be 0
    defaultVotingSettings = IDAOSpace.VotingSettings({
      slowPathPercentageThreshold: 5e5, // 50%
      fastPathFlatThreshold: 0,
      quorum: 0,
      duration: 2 days
    });

    // Create EOA actors
    eoaActors = new address[](3);
    for (uint256 i = 0; i < eoaActors.length; i++) {
      eoaActors[i] = makeAddr(string.concat('eoa', vm.toString(i)));
    }

    // Create DAOSpace actors
    // Note: Initial editors must already be registered spaces, so we pass empty arrays
    daoSpaceActors = new address[](2);
    for (uint256 i = 0; i < daoSpaceActors.length; i++) {
      address daoSpace = daoSpaceFactoryProxy.createDAOSpaceProxy(
        defaultVotingSettings,
        new address[](0), // no initial editors (they must be registered spaces)
        new address[](0), // no initial members
        '', // editsContentUri
        '' // editsMetadata
      );
      daoSpaceActors[i] = daoSpace;
    }

    // Create VerifierSpace actors
    verifierSpaceActors = new address[](2);
    verifierSpaceOwnerKeys = new uint256[](2);
    for (uint256 i = 0; i < verifierSpaceActors.length; i++) {
      // Use makeAddrAndKey to get both address and private key
      (address spaceOwner, uint256 ownerKey) = makeAddrAndKey(string.concat('verifierSpaceOwner', vm.toString(i)));
      verifierSpaceOwnerKeys[i] = ownerKey;
      address verifierSpace = verifierSpaceFactoryProxy.createVerifierSpaceProxy(spaceOwner);
      verifierSpaceActors[i] = verifierSpace;
    }

    // Configure Fuzzer:
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
