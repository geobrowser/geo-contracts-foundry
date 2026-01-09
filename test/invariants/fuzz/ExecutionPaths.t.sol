// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Setup} from './Setup.t.sol';
import {DAOSpace} from 'contracts/DAOSpace.sol';
import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import 'script/Constants.s.sol' as Constants;

/// @title ExecutionPaths
/// @notice Validates that handlers can execute their intended paths
/// @dev This is an indirect way to check for code coverage - all paths must be executable
///      using only the handlers. If a test here fails, the handler is likely broken.
contract ExecutionPaths is Setup {
  /// @notice Verify setup completed correctly
  function test_setup() public view {
    // SpaceRegistry should be deployed and initialized
    assertGt(address(spaceRegistryProxy).code.length, 0);
    assertEq(spaceRegistryProxy.owner(), Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL);

    // Handler should be deployed
    assertGt(address(handlerSpaceRegistry).code.length, 0);

    // SpaceRegistry should have registered itself during initialization
    bytes16 registrySpaceId = spaceRegistryProxy.addressToSpaceId(address(spaceRegistryProxy));
    assertNotEq(registrySpaceId, bytes16(0), 'SpaceRegistry should be self-registered');

    // EOA actors should not be registered initially
    for (uint256 i = 0; i < eoaActors.length; i++) {
      assertEq(spaceRegistryProxy.addressToSpaceId(eoaActors[i]), bytes16(0));
    }

    // DAOSpace actors should be pre-registered by factory
    for (uint256 i = 0; i < daoSpaceActors.length; i++) {
      bytes16 spaceId = spaceRegistryProxy.addressToSpaceId(daoSpaceActors[i]);
      assertNotEq(spaceId, bytes16(0), 'DAOSpace should be pre-registered');
    }

    // VerifierSpace actors should be pre-registered by factory
    for (uint256 i = 0; i < verifierSpaceActors.length; i++) {
      bytes16 spaceId = spaceRegistryProxy.addressToSpaceId(verifierSpaceActors[i]);
      assertNotEq(spaceId, bytes16(0), 'VerifierSpace should be pre-registered');
    }
  }

  /// @notice Test that pre-registered Space contracts are tracked in ghost state
  function test_preRegistered_spaces_tracked() public view {
    // Check ghost state tracks factory-created spaces
    assertEq(
      handlerSpaceRegistry.ghost_factoryCreatedSpaces(),
      daoSpaceActors.length + verifierSpaceActors.length,
      'Factory created spaces should be tracked'
    );

    // DAOSpaces should be tracked
    for (uint256 i = 0; i < daoSpaceActors.length; i++) {
      assertTrue(
        handlerSpaceRegistry.ghost_isAddressRegistered(daoSpaceActors[i]), 'DAOSpace should be tracked as registered'
      );
      assertTrue(handlerSpaceRegistry.isDAOSpace(daoSpaceActors[i]), 'DAOSpace should be identified as DAOSpace');
    }

    // VerifierSpaces should be tracked
    for (uint256 i = 0; i < verifierSpaceActors.length; i++) {
      assertTrue(
        handlerSpaceRegistry.ghost_isAddressRegistered(verifierSpaceActors[i]),
        'VerifierSpace should be tracked as registered'
      );
      assertTrue(
        handlerSpaceRegistry.isVerifierSpace(verifierSpaceActors[i]),
        'VerifierSpace should be identified as VerifierSpace'
      );
    }
  }

  /// @notice Test that registerSpaceId handler works for EOAs
  function test_handler_registerSpaceId() public {
    address actor = eoaActors[0];

    // Actor should not be registered initially
    assertEq(spaceRegistryProxy.addressToSpaceId(actor), bytes16(0));

    // Call handler
    vm.prank(actor);
    handlerSpaceRegistry.handler_registerSpaceId();

    // Should have succeeded
    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'registerSpaceId should succeed');

    // Actor should now be registered
    bytes16 spaceId = spaceRegistryProxy.addressToSpaceId(actor);
    assertNotEq(spaceId, bytes16(0), 'Actor should have spaceId');

    // Bidirectional mapping should be correct
    assertEq(spaceRegistryProxy.spaceIdToAddress(spaceId), actor);

    // Ghost state should be updated
    assertTrue(handlerSpaceRegistry.ghost_isAddressRegistered(actor));
    assertTrue(handlerSpaceRegistry.ghost_isSpaceIdRegistered(spaceId));
    assertEq(handlerSpaceRegistry.ghost_totalRegistrations(), 1);
  }

  /// @notice Test that clearSpaceId handler works for EOAs
  function test_handler_clearSpaceId_eoa() public {
    address actor = eoaActors[0];

    // First register
    vm.prank(actor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());

    bytes16 spaceId = spaceRegistryProxy.addressToSpaceId(actor);

    // Now clear
    vm.prank(actor);
    handlerSpaceRegistry.handler_clearSpaceId();

    // Should have succeeded
    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'clearSpaceId should succeed');

    // Mappings should be cleared
    assertEq(spaceRegistryProxy.addressToSpaceId(actor), bytes16(0));
    assertEq(spaceRegistryProxy.spaceIdToAddress(spaceId), address(0));

    // Ghost state should be updated
    assertFalse(handlerSpaceRegistry.ghost_isAddressRegistered(actor));
    assertFalse(handlerSpaceRegistry.ghost_isSpaceIdRegistered(spaceId));
    assertEq(handlerSpaceRegistry.ghost_totalClears(), 1);
  }

  /// @notice Test the full migration flow with EOAs
  function test_handler_migration_flow() public {
    address oldActor = eoaActors[0];
    address newActor = eoaActors[1];

    // Register old actor
    vm.prank(oldActor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());

    bytes16 spaceId = spaceRegistryProxy.addressToSpaceId(oldActor);

    // Propose migration (oldActor proposes to migrate to newActor)
    vm.prank(oldActor);
    handlerSpaceRegistry.handler_proposeSpaceMigration(1); // seed=1 should find newActor

    // Verify proposal was recorded
    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(spaceId), newActor);

    // Accept migration (newActor accepts)
    vm.prank(newActor);
    handlerSpaceRegistry.handler_acceptSpaceMigration();

    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'acceptSpaceMigration should succeed');

    // Verify migration completed
    assertEq(spaceRegistryProxy.addressToSpaceId(oldActor), bytes16(0));
    assertEq(spaceRegistryProxy.addressToSpaceId(newActor), spaceId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(spaceId), newActor);

    // Ghost state should reflect migration
    assertFalse(handlerSpaceRegistry.ghost_isAddressRegistered(oldActor));
    assertTrue(handlerSpaceRegistry.ghost_isAddressRegistered(newActor));
    assertEq(handlerSpaceRegistry.ghost_migrations(oldActor), newActor);
  }

  /// @notice Test multiple EOA registrations and clears
  function test_handler_multiple_operations() public {
    // Register all EOA actors
    for (uint256 i = 0; i < eoaActors.length; i++) {
      vm.prank(eoaActors[i]);
      handlerSpaceRegistry.handler_registerSpaceId();
      assertTrue(handlerSpaceRegistry.lastTxSucceeded());
    }

    assertEq(handlerSpaceRegistry.ghost_totalRegistrations(), eoaActors.length);

    // Clear one actor
    vm.prank(eoaActors[1]);
    handlerSpaceRegistry.handler_clearSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());

    assertEq(handlerSpaceRegistry.ghost_totalClears(), 1);

    // Re-register the cleared actor
    vm.prank(eoaActors[1]);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());

    assertEq(handlerSpaceRegistry.ghost_totalRegistrations(), eoaActors.length + 1);
  }

  /// @notice Test that duplicate registration is handled gracefully
  function test_handler_duplicate_register_skipped() public {
    address actor = eoaActors[0];

    // First registration
    vm.prank(actor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());

    // Second registration attempt should be skipped (not cause revert)
    vm.prank(actor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertFalse(handlerSpaceRegistry.lastTxSucceeded(), 'Duplicate should be skipped');

    // Should still only have 1 registration
    assertEq(handlerSpaceRegistry.ghost_totalRegistrations(), 1);
  }

  /// @notice Test that clearing unregistered address is handled gracefully
  function test_handler_clear_unregistered_skipped() public {
    address actor = eoaActors[0];

    // Try to clear without registering first
    vm.prank(actor);
    handlerSpaceRegistry.handler_clearSpaceId();
    assertFalse(handlerSpaceRegistry.lastTxSucceeded(), 'Clear unregistered should be skipped');
  }

  /// @notice Test that actor type detection works correctly
  function test_actor_type_detection() public view {
    // EOAs should be identified correctly
    for (uint256 i = 0; i < eoaActors.length; i++) {
      assertTrue(handlerSpaceRegistry.isEOA(eoaActors[i]), 'Should be EOA');
      assertFalse(handlerSpaceRegistry.isSpaceContract(eoaActors[i]), 'Should not be Space');
    }

    // DAOSpaces should be identified correctly
    for (uint256 i = 0; i < daoSpaceActors.length; i++) {
      assertFalse(handlerSpaceRegistry.isEOA(daoSpaceActors[i]), 'Should not be EOA');
      assertTrue(handlerSpaceRegistry.isDAOSpace(daoSpaceActors[i]), 'Should be DAOSpace');
      assertTrue(handlerSpaceRegistry.isSpaceContract(daoSpaceActors[i]), 'Should be Space');
    }

    // VerifierSpaces should be identified correctly
    for (uint256 i = 0; i < verifierSpaceActors.length; i++) {
      assertFalse(handlerSpaceRegistry.isEOA(verifierSpaceActors[i]), 'Should not be EOA');
      assertTrue(handlerSpaceRegistry.isVerifierSpace(verifierSpaceActors[i]), 'Should be VerifierSpace');
      assertTrue(handlerSpaceRegistry.isSpaceContract(verifierSpaceActors[i]), 'Should be Space');
    }
  }

  // ==================== DAOSpace Handler Tests ====================

  /// @notice Test that addEditor handler works
  function test_handler_daoSpace_addEditor() public {
    address daoSpace = daoSpaceActors[0];
    address newEditor = eoaActors[0];

    // First register the EOA so it can be an editor
    vm.prank(newEditor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'EOA registration should succeed');

    // Verify not an editor yet
    DAOSpace dao = DAOSpace(daoSpace);
    assertFalse(dao.hasRole(dao.EDITOR(), newEditor), 'Should not be editor yet');

    // Add as editor
    vm.prank(newEditor);
    handlerDAOSpace.handler_daoSpace_addEditor(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'addEditor should succeed');

    // Verify now an editor
    assertTrue(dao.hasRole(dao.EDITOR(), newEditor), 'Should be editor now');
    assertEq(dao.totalEditors(), 1, 'Should have 1 editor');
  }

  /// @notice Test that addMember handler works
  function test_handler_daoSpace_addMember() public {
    address daoSpace = daoSpaceActors[0];
    address newMember = eoaActors[0];

    // First register the EOA
    vm.prank(newMember);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());

    // Verify not a member yet
    DAOSpace dao = DAOSpace(daoSpace);
    assertFalse(dao.hasRole(dao.MEMBER(), newMember), 'Should not be member yet');

    // Add as member
    vm.prank(newMember);
    handlerDAOSpace.handler_daoSpace_addMember(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'addMember should succeed');

    // Verify now a member
    assertTrue(dao.hasRole(dao.MEMBER(), newMember), 'Should be member now');
  }

  /// @notice Test the full DAOSpace governance flow: add editor -> create proposal -> vote
  function test_handler_daoSpace_governance_flow() public {
    address daoSpace = daoSpaceActors[0];
    address editor = eoaActors[0];

    // 1. Register EOA
    vm.prank(editor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());

    // 2. Add as editor
    vm.prank(editor);
    handlerDAOSpace.handler_daoSpace_addEditor(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'addEditor should succeed');

    // 3. Create a slow path proposal (editor can create)
    vm.prank(editor);
    handlerDAOSpace.handler_daoSpace_createProposal(0, 0); // seed 0 = slow path
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'createProposal should succeed');

    // Verify proposal was created
    assertEq(handlerDAOSpace.getActiveProposalsCount(daoSpace), 1, 'Should have 1 proposal');

    // 4. Vote on proposal
    vm.prank(editor);
    handlerDAOSpace.handler_daoSpace_vote(0, 0, 2); // vote Yes
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'vote should succeed');

    // Verify vote was recorded in ghost state
    bytes16 proposalId = handlerDAOSpace.getActiveProposal(daoSpace, 0);
    assertEq(handlerDAOSpace.ghost_yesVotes(proposalId), 1, 'Should have 1 yes vote');
  }

  /// @notice Test that unregistered EOA cannot be added as editor
  function test_handler_daoSpace_addEditor_unregistered_skipped() public {
    address newEditor = eoaActors[0];

    // Try to add unregistered EOA as editor
    vm.prank(newEditor);
    handlerDAOSpace.handler_daoSpace_addEditor(0, 0);
    assertFalse(handlerDAOSpace.lastTxSucceeded(), 'Should skip unregistered');
  }

  /// @notice Test that non-editor cannot create fast path proposal
  function test_handler_daoSpace_createProposal_nonEditor_slowPath() public {
    address daoSpace = daoSpaceActors[0];
    address member = eoaActors[0];

    // Register and add as member (not editor)
    vm.prank(member);
    handlerSpaceRegistry.handler_registerSpaceId();

    vm.prank(member);
    handlerDAOSpace.handler_daoSpace_addMember(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded());

    // Member can create slow path proposal
    vm.prank(member);
    handlerDAOSpace.handler_daoSpace_createProposal(0, 0); // slow path
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'Member should create slow path');

    // But fast path should fail (seed 1 = fast path)
    vm.prank(member);
    handlerDAOSpace.handler_daoSpace_createProposal(0, 1); // fast path
    assertFalse(handlerDAOSpace.lastTxSucceeded(), 'Member should not create fast path');
  }

  // ==================== VerifierSpace Handler Tests ====================

  /// @notice Test that VerifierSpace enter handler works with valid signature
  function test_handler_verifierSpace_enter() public {
    address verifierSpace = verifierSpaceActors[0];
    address caller = eoaActors[0];

    // Register caller first
    vm.prank(caller);
    handlerSpaceRegistry.handler_registerSpaceId();

    VerifierSpace vs = VerifierSpace(verifierSpace);
    uint256 nonceBefore = vs.replayNonce();

    // Call enter with valid signature
    vm.prank(caller);
    handlerVerifierSpace.handler_verifierSpace_enter(0, 0);
    assertTrue(handlerVerifierSpace.lastTxSucceeded(), 'enter should succeed');

    // Verify nonce increased
    uint256 nonceAfter = vs.replayNonce();
    assertEq(nonceAfter, nonceBefore + 1, 'Nonce should increase by 1');

    // Verify ghost state
    assertEq(handlerVerifierSpace.ghost_successfulVerifyCalls(), 1, 'Should have 1 successful call');
  }

  /// @notice Test that replay attack fails
  function test_handler_verifierSpace_replayAttack() public {
    address verifierSpace = verifierSpaceActors[0];
    address caller = eoaActors[0];

    // Register caller
    vm.prank(caller);
    handlerSpaceRegistry.handler_registerSpaceId();

    // First do a successful enter to increment nonce
    vm.prank(caller);
    handlerVerifierSpace.handler_verifierSpace_enter(0, 0);
    assertTrue(handlerVerifierSpace.lastTxSucceeded());

    // Now try replay attack (using old nonce)
    vm.prank(caller);
    handlerVerifierSpace.handler_verifierSpace_replayAttack(0);

    // Replay should fail
    assertFalse(handlerVerifierSpace.lastTxSucceeded(), 'Replay attack should fail');
  }

  /// @notice Test multiple VerifierSpace enters increment nonce correctly
  function test_handler_verifierSpace_multiple_enters() public {
    address verifierSpace = verifierSpaceActors[0];
    address caller = eoaActors[0];

    // Register caller
    vm.prank(caller);
    handlerSpaceRegistry.handler_registerSpaceId();

    VerifierSpace vs = VerifierSpace(verifierSpace);
    uint256 initialNonce = vs.replayNonce();

    // Do multiple enters
    for (uint256 i = 0; i < 3; i++) {
      vm.prank(caller);
      handlerVerifierSpace.handler_verifierSpace_enter(0, 0);
      assertTrue(handlerVerifierSpace.lastTxSucceeded(), 'Enter should succeed');
    }

    // Nonce should have increased by 3
    assertEq(vs.replayNonce(), initialNonce + 3, 'Nonce should increase by 3');
    assertEq(handlerVerifierSpace.ghost_successfulVerifyCalls(), 3, 'Should have 3 successful calls');
  }
}
