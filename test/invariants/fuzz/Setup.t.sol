// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {Test} from 'forge-std/Test.sol';

import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {DeployGEOBrowser} from 'script/DeployGEOBrowser.s.sol';

import {HandlerBlockchain} from 'test/invariants/fuzz/handlers/HandlerBlockchain.t.sol';
import {HandlerDAOSpace} from 'test/invariants/fuzz/handlers/HandlerDAOSpace.t.sol';
import {HandlerSpaceRegistry} from 'test/invariants/fuzz/handlers/HandlerSpaceRegistry.t.sol';
import {HandlerVerifierSpace} from 'test/invariants/fuzz/handlers/HandlerVerifierSpace.t.sol';

contract Setup is Test, DeployGEOBrowser {
  uint256 internal constant _NUM_EOA_ACTORS = 3;
  uint256 internal constant _NUM_DAO_SPACE_ACTORS = 2;
  uint256 internal constant _NUM_VERIFIER_SPACE_ACTORS = 2;

  HandlerBlockchain public handlerBlockchain;
  HandlerSpaceRegistry public handlerSpaceRegistry;
  HandlerDAOSpace public handlerDAOSpace;
  HandlerVerifierSpace public handlerVerifierSpace;

  address[] public eoaActors;
  address[] public daoSpaceActors;
  address[] public verifierSpaceActors;
  uint256[] public verifierSpaceOwnerKeys;

  IDAOSpace.VotingSettings internal _defaultVotingSettings;

  function setUp() public virtual {
    DeployGEOBrowser.run();

    _initializeVotingSettings();
    _createEOAActors();
    _createDAOSpaceActors();
    _createVerifierSpaceActors();
    _configureTargets();
  }

  function _initializeVotingSettings() internal {
    // quorum and flatSupportThreshold must be <= totalEditors
    // Since we create DAOSpaces with 0 initial editors, these must be 0
    _defaultVotingSettings = IDAOSpace.VotingSettings({
      partialPercentageSupportThreshold: 5e5, // 5%
      universalPercentageSupportThreshold: 5e5, // 5%
      flatSupportThreshold: 0,
      quorum: 0,
      duration: 2 days,
      disableFastPathAccessForNewMembers: false,
      executionGracePeriod: 7 days
    });
  }

  function _createEOAActors() internal {
    eoaActors = new address[](_NUM_EOA_ACTORS);
    for (uint256 _i = 0; _i < _NUM_EOA_ACTORS; _i++) {
      eoaActors[_i] = makeAddr(string.concat('eoa', vm.toString(_i)));
    }
  }

  function _createDAOSpaceActors() internal {
    // Initial editors must already be registered spaces, so we pass empty arrays
    daoSpaceActors = new address[](_NUM_DAO_SPACE_ACTORS);
    for (uint256 _i = 0; _i < _NUM_DAO_SPACE_ACTORS; _i++) {
      daoSpaceActors[_i] = daoSpaceFactoryProxy.createDAOSpaceProxy(
        _defaultVotingSettings, new bytes16[](0), new bytes16[](0), '', '', bytes16(0)
      );
    }
  }

  function _createVerifierSpaceActors() internal {
    verifierSpaceActors = new address[](_NUM_VERIFIER_SPACE_ACTORS);
    verifierSpaceOwnerKeys = new uint256[](_NUM_VERIFIER_SPACE_ACTORS);
    for (uint256 _i = 0; _i < _NUM_VERIFIER_SPACE_ACTORS; _i++) {
      (address _spaceOwner, uint256 _ownerKey) = makeAddrAndKey(string.concat('verifierSpaceOwner', vm.toString(_i)));
      verifierSpaceOwnerKeys[_i] = _ownerKey;
      verifierSpaceActors[_i] = verifierSpaceFactoryProxy.createVerifierSpaceProxy(_spaceOwner);
    }
  }

  function _configureTargets() internal {
    for (uint256 _i = 0; _i < eoaActors.length; _i++) {
      targetSender(eoaActors[_i]);
    }

    handlerBlockchain = new HandlerBlockchain();
    handlerSpaceRegistry = new HandlerSpaceRegistry(spaceRegistryProxy, eoaActors, daoSpaceActors, verifierSpaceActors);
    handlerDAOSpace = new HandlerDAOSpace(spaceRegistryProxy, eoaActors, daoSpaceActors, verifierSpaceActors);
    handlerVerifierSpace = new HandlerVerifierSpace(
      spaceRegistryProxy, eoaActors, daoSpaceActors, verifierSpaceActors, verifierSpaceOwnerKeys
    );

    targetContract(address(handlerBlockchain));
    targetContract(address(handlerSpaceRegistry));
    targetContract(address(handlerDAOSpace));
    targetContract(address(handlerVerifierSpace));
  }
}
