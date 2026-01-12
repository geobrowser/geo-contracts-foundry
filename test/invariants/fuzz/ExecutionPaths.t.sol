// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.30;

import {Setup} from './Setup.t.sol';
import {DAOSpace} from 'contracts/DAOSpace.sol';
import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import 'script/Constants.s.sol' as Constants;

/// @title ExecutionPaths
/// @notice Validates that handlers can execute their intended paths
/// @dev Indirect code coverage check - all paths must be executable via handlers
contract ExecutionPaths is Setup {
  function test_setup() public view {
    assertGt(address(spaceRegistryProxy).code.length, 0);
    assertEq(spaceRegistryProxy.owner(), Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL);
    assertGt(address(handlerSpaceRegistry).code.length, 0);

    bytes16 registrySpaceId = spaceRegistryProxy.addressToSpaceId(address(spaceRegistryProxy));
    assertNotEq(registrySpaceId, bytes16(0), 'SpaceRegistry should be self-registered');

    _assertEOAsNotRegistered();
    _assertDAOSpacesRegistered();
    _assertVerifierSpacesRegistered();
  }

  function _assertEOAsNotRegistered() internal view {
    for (uint256 i = 0; i < eoaActors.length; i++) {
      assertEq(spaceRegistryProxy.addressToSpaceId(eoaActors[i]), bytes16(0));
    }
  }

  function _assertDAOSpacesRegistered() internal view {
    for (uint256 i = 0; i < daoSpaceActors.length; i++) {
      assertNotEq(
        spaceRegistryProxy.addressToSpaceId(daoSpaceActors[i]), bytes16(0), 'DAOSpace should be pre-registered'
      );
    }
  }

  function _assertVerifierSpacesRegistered() internal view {
    for (uint256 i = 0; i < verifierSpaceActors.length; i++) {
      assertNotEq(
        spaceRegistryProxy.addressToSpaceId(verifierSpaceActors[i]),
        bytes16(0),
        'VerifierSpace should be pre-registered'
      );
    }
  }

  function test_preRegistered_spaces_tracked() public view {
    assertEq(
      handlerSpaceRegistry.ghost_factoryCreatedSpaces(),
      daoSpaceActors.length + verifierSpaceActors.length,
      'Factory created spaces should be tracked'
    );

    for (uint256 i = 0; i < daoSpaceActors.length; i++) {
      assertTrue(handlerSpaceRegistry.ghost_isAddressRegistered(daoSpaceActors[i]), 'DAOSpace should be tracked');
      assertTrue(handlerSpaceRegistry.isDAOSpace(daoSpaceActors[i]), 'Should be identified as DAOSpace');
    }

    for (uint256 i = 0; i < verifierSpaceActors.length; i++) {
      assertTrue(
        handlerSpaceRegistry.ghost_isAddressRegistered(verifierSpaceActors[i]), 'VerifierSpace should be tracked'
      );
      assertTrue(handlerSpaceRegistry.isVerifierSpace(verifierSpaceActors[i]), 'Should be identified as VerifierSpace');
    }
  }

  function test_handler_registerSpaceId() public {
    address actor = eoaActors[0];
    assertEq(spaceRegistryProxy.addressToSpaceId(actor), bytes16(0));

    vm.prank(actor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'registerSpaceId should succeed');

    bytes16 spaceId = spaceRegistryProxy.addressToSpaceId(actor);
    assertNotEq(spaceId, bytes16(0), 'Actor should have spaceId');
    assertEq(spaceRegistryProxy.spaceIdToAddress(spaceId), actor);
    assertTrue(handlerSpaceRegistry.ghost_isAddressRegistered(actor));
    assertTrue(handlerSpaceRegistry.ghost_isSpaceIdRegistered(spaceId));
    assertEq(handlerSpaceRegistry.ghost_totalRegistrations(), 1);
  }

  function test_handler_clearSpaceId_eoa() public {
    address actor = eoaActors[0];

    vm.prank(actor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());
    bytes16 spaceId = spaceRegistryProxy.addressToSpaceId(actor);

    vm.prank(actor);
    handlerSpaceRegistry.handler_clearSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'clearSpaceId should succeed');

    assertEq(spaceRegistryProxy.addressToSpaceId(actor), bytes16(0));
    assertEq(spaceRegistryProxy.spaceIdToAddress(spaceId), address(0));
    assertFalse(handlerSpaceRegistry.ghost_isAddressRegistered(actor));
    assertFalse(handlerSpaceRegistry.ghost_isSpaceIdRegistered(spaceId));
    assertEq(handlerSpaceRegistry.ghost_totalClears(), 1);
  }

  function test_handler_migration_flow() public {
    address oldActor = eoaActors[0];
    address newActor = eoaActors[1];

    vm.prank(oldActor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());
    bytes16 spaceId = spaceRegistryProxy.addressToSpaceId(oldActor);

    vm.prank(oldActor);
    handlerSpaceRegistry.handler_proposeSpaceMigration(1);
    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(spaceId), newActor);

    vm.prank(newActor);
    handlerSpaceRegistry.handler_acceptSpaceMigration();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'acceptSpaceMigration should succeed');

    assertEq(spaceRegistryProxy.addressToSpaceId(oldActor), bytes16(0));
    assertEq(spaceRegistryProxy.addressToSpaceId(newActor), spaceId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(spaceId), newActor);
    assertFalse(handlerSpaceRegistry.ghost_isAddressRegistered(oldActor));
    assertTrue(handlerSpaceRegistry.ghost_isAddressRegistered(newActor));
    assertEq(handlerSpaceRegistry.ghost_migrations(oldActor), newActor);
  }

  function test_handler_multiple_operations() public {
    for (uint256 i = 0; i < eoaActors.length; i++) {
      vm.prank(eoaActors[i]);
      handlerSpaceRegistry.handler_registerSpaceId();
      assertTrue(handlerSpaceRegistry.lastTxSucceeded());
    }
    assertEq(handlerSpaceRegistry.ghost_totalRegistrations(), eoaActors.length);

    vm.prank(eoaActors[1]);
    handlerSpaceRegistry.handler_clearSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());
    assertEq(handlerSpaceRegistry.ghost_totalClears(), 1);

    vm.prank(eoaActors[1]);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());
    assertEq(handlerSpaceRegistry.ghost_totalRegistrations(), eoaActors.length + 1);
  }

  function test_handler_duplicate_register_skipped() public {
    address actor = eoaActors[0];

    vm.prank(actor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());

    vm.prank(actor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertFalse(handlerSpaceRegistry.lastTxSucceeded(), 'Duplicate should be skipped');
    assertEq(handlerSpaceRegistry.ghost_totalRegistrations(), 1);
  }

  function test_handler_clear_unregistered_skipped() public {
    vm.prank(eoaActors[0]);
    handlerSpaceRegistry.handler_clearSpaceId();
    assertFalse(handlerSpaceRegistry.lastTxSucceeded(), 'Clear unregistered should be skipped');
  }

  function test_actor_type_detection() public view {
    for (uint256 i = 0; i < eoaActors.length; i++) {
      assertTrue(handlerSpaceRegistry.isEOA(eoaActors[i]), 'Should be EOA');
      assertFalse(handlerSpaceRegistry.isSpaceContract(eoaActors[i]), 'Should not be Space');
    }

    for (uint256 i = 0; i < daoSpaceActors.length; i++) {
      assertFalse(handlerSpaceRegistry.isEOA(daoSpaceActors[i]), 'Should not be EOA');
      assertTrue(handlerSpaceRegistry.isDAOSpace(daoSpaceActors[i]), 'Should be DAOSpace');
      assertTrue(handlerSpaceRegistry.isSpaceContract(daoSpaceActors[i]), 'Should be Space');
    }

    for (uint256 i = 0; i < verifierSpaceActors.length; i++) {
      assertFalse(handlerSpaceRegistry.isEOA(verifierSpaceActors[i]), 'Should not be EOA');
      assertTrue(handlerSpaceRegistry.isVerifierSpace(verifierSpaceActors[i]), 'Should be VerifierSpace');
      assertTrue(handlerSpaceRegistry.isSpaceContract(verifierSpaceActors[i]), 'Should be Space');
    }
  }

  // ==================== DAOSpace Handler Tests ====================

  function test_handler_daoSpace_addEditor() public {
    address newEditor = eoaActors[0];
    DAOSpace dao = DAOSpace(daoSpaceActors[0]);

    vm.prank(newEditor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'EOA registration should succeed');
    bytes16 editorSpaceId = spaceRegistryProxy.addressToSpaceId(newEditor);
    assertFalse(dao.hasRole(dao.EDITOR(), editorSpaceId), 'Should not be editor yet');

    vm.prank(newEditor);
    handlerDAOSpace.handler_daoSpace_addEditor(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'addEditor should succeed');
    assertTrue(dao.hasRole(dao.EDITOR(), editorSpaceId), 'Should be editor now');
    assertEq(dao.totalEditors(), 1, 'Should have 1 editor');
  }

  function test_handler_daoSpace_addMember() public {
    address newMember = eoaActors[0];
    DAOSpace dao = DAOSpace(daoSpaceActors[0]);

    vm.prank(newMember);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());
    bytes16 memberSpaceId = spaceRegistryProxy.addressToSpaceId(newMember);
    assertFalse(dao.hasRole(dao.MEMBER(), memberSpaceId), 'Should not be member yet');

    vm.prank(newMember);
    handlerDAOSpace.handler_daoSpace_addMember(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'addMember should succeed');
    assertTrue(dao.hasRole(dao.MEMBER(), memberSpaceId), 'Should be member now');
  }

  function test_handler_daoSpace_governance_flow() public {
    address daoSpace = daoSpaceActors[0];
    address editor = eoaActors[0];

    vm.prank(editor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());

    vm.prank(editor);
    handlerDAOSpace.handler_daoSpace_addEditor(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'addEditor should succeed');

    vm.prank(editor);
    handlerDAOSpace.handler_daoSpace_createProposal(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'createProposal should succeed');
    assertEq(handlerDAOSpace.getActiveProposalsCount(daoSpace), 1, 'Should have 1 proposal');

    vm.prank(editor);
    handlerDAOSpace.handler_daoSpace_vote(0, 0, 2);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'vote should succeed');

    bytes16 proposalId = handlerDAOSpace.getActiveProposal(daoSpace, 0);
    assertEq(handlerDAOSpace.ghost_yesVotes(proposalId), 1, 'Should have 1 yes vote');
  }

  function test_handler_daoSpace_addEditor_unregistered_skipped() public {
    vm.prank(eoaActors[0]);
    handlerDAOSpace.handler_daoSpace_addEditor(0, 0);
    assertFalse(handlerDAOSpace.lastTxSucceeded(), 'Should skip unregistered');
  }

  function test_handler_daoSpace_createProposal_nonEditor_slowPath() public {
    address member = eoaActors[0];

    vm.prank(member);
    handlerSpaceRegistry.handler_registerSpaceId();

    vm.prank(member);
    handlerDAOSpace.handler_daoSpace_addMember(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded());

    vm.prank(member);
    handlerDAOSpace.handler_daoSpace_createProposal(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'Member should create slow path');

    vm.prank(member);
    handlerDAOSpace.handler_daoSpace_createProposal(0, 1);
    assertFalse(handlerDAOSpace.lastTxSucceeded(), 'Member should not create fast path');
  }

  // ==================== VerifierSpace Handler Tests ====================

  function test_handler_verifierSpace_enter() public {
    address caller = eoaActors[0];
    VerifierSpace vs = VerifierSpace(verifierSpaceActors[0]);

    vm.prank(caller);
    handlerSpaceRegistry.handler_registerSpaceId();

    uint256 nonceBefore = vs.replayNonce();

    vm.prank(caller);
    handlerVerifierSpace.handler_verifierSpace_enter(0, 0);
    assertTrue(handlerVerifierSpace.lastTxSucceeded(), 'enter should succeed');
    assertEq(vs.replayNonce(), nonceBefore + 1, 'Nonce should increase by 1');
    assertEq(handlerVerifierSpace.ghost_successfulVerifyCalls(), 1, 'Should have 1 successful call');
  }

  function test_handler_verifierSpace_replayAttack() public {
    address caller = eoaActors[0];

    vm.prank(caller);
    handlerSpaceRegistry.handler_registerSpaceId();

    vm.prank(caller);
    handlerVerifierSpace.handler_verifierSpace_enter(0, 0);
    assertTrue(handlerVerifierSpace.lastTxSucceeded());

    vm.prank(caller);
    handlerVerifierSpace.handler_verifierSpace_replayAttack(0);
    assertFalse(handlerVerifierSpace.lastTxSucceeded(), 'Replay attack should fail');
  }

  function test_handler_verifierSpace_multiple_enters() public {
    address caller = eoaActors[0];
    VerifierSpace vs = VerifierSpace(verifierSpaceActors[0]);

    vm.prank(caller);
    handlerSpaceRegistry.handler_registerSpaceId();

    uint256 initialNonce = vs.replayNonce();

    for (uint256 i = 0; i < 3; i++) {
      vm.prank(caller);
      handlerVerifierSpace.handler_verifierSpace_enter(0, 0);
      assertTrue(handlerVerifierSpace.lastTxSucceeded(), 'Enter should succeed');
    }

    assertEq(vs.replayNonce(), initialNonce + 3, 'Nonce should increase by 3');
    assertEq(handlerVerifierSpace.ghost_successfulVerifyCalls(), 3, 'Should have 3 successful calls');
  }
}
