// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.30;

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import 'script/Constants.s.sol' as Constants;
import {Setup} from 'test/invariants/fuzz/Setup.t.sol';

/// @title ExecutionPaths
/// @notice Validates that handlers can execute their intended paths
/// @dev Indirect code coverage check - all paths must be executable via handlers
contract ExecutionPaths is Setup {
  function test_setup() public view {
    assertGt(address(spaceRegistryProxy).code.length, 0);
    assertEq(spaceRegistryProxy.owner(), Constants.GEO_GEO_MULTISIG_COUNCIL);
    assertGt(address(handlerSpaceRegistry).code.length, 0);

    bytes16 _registrySpaceId = spaceRegistryProxy.addressToSpaceId(address(spaceRegistryProxy));
    assertNotEq(_registrySpaceId, bytes16(0), 'SpaceRegistry should be self-registered');

    _assertEOAsNotRegistered();
    _assertDAOSpacesRegistered();
    _assertVerifierSpacesRegistered();
  }

  function _assertEOAsNotRegistered() internal view {
    for (uint256 _i = 0; _i < eoaActors.length; _i++) {
      assertEq(spaceRegistryProxy.addressToSpaceId(eoaActors[_i]), bytes16(0));
    }
  }

  function _assertDAOSpacesRegistered() internal view {
    for (uint256 _i = 0; _i < daoSpaceActors.length; _i++) {
      assertNotEq(
        spaceRegistryProxy.addressToSpaceId(daoSpaceActors[_i]), bytes16(0), 'DAOSpace should be pre-registered'
      );
    }
  }

  function _assertVerifierSpacesRegistered() internal view {
    for (uint256 _i = 0; _i < verifierSpaceActors.length; _i++) {
      assertNotEq(
        spaceRegistryProxy.addressToSpaceId(verifierSpaceActors[_i]),
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

    for (uint256 _i = 0; _i < daoSpaceActors.length; _i++) {
      assertTrue(handlerSpaceRegistry.ghost_isAddressRegistered(daoSpaceActors[_i]), 'DAOSpace should be tracked');
      assertTrue(handlerSpaceRegistry.isDAOSpace(daoSpaceActors[_i]), 'Should be identified as DAOSpace');
    }

    for (uint256 _i = 0; _i < verifierSpaceActors.length; _i++) {
      assertTrue(
        handlerSpaceRegistry.ghost_isAddressRegistered(verifierSpaceActors[_i]), 'VerifierSpace should be tracked'
      );
      assertTrue(handlerSpaceRegistry.isVerifierSpace(verifierSpaceActors[_i]), 'Should be identified as VerifierSpace');
    }
  }

  function test_handler_registerSpaceId() public {
    address _actor = eoaActors[0];
    assertEq(spaceRegistryProxy.addressToSpaceId(_actor), bytes16(0));

    vm.prank(_actor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'registerSpaceId should succeed');

    bytes16 _spaceId = spaceRegistryProxy.addressToSpaceId(_actor);
    assertNotEq(_spaceId, bytes16(0), 'Actor should have spaceId');
    assertEq(spaceRegistryProxy.spaceIdToAddress(_spaceId), _actor);
    assertTrue(handlerSpaceRegistry.ghost_isAddressRegistered(_actor));
    assertTrue(handlerSpaceRegistry.ghost_isSpaceIdRegistered(_spaceId));
    assertEq(handlerSpaceRegistry.ghost_totalRegistrations(), 1);
  }

  function test_handler_archiveSpaceId_eoa() public {
    address _actor = eoaActors[0];

    vm.prank(_actor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());
    bytes16 _spaceId = spaceRegistryProxy.addressToSpaceId(_actor);
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_spaceId), 'Should not be archived initially');

    vm.prank(_actor);
    handlerSpaceRegistry.handler_archiveSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'archiveSpaceId should succeed');

    assertTrue(spaceRegistryProxy.archivedSpaceIds(_spaceId), 'Should be archived');
    assertTrue(spaceRegistryProxy.registeredSpaceIds(_spaceId), 'Should still be registered');
    assertFalse(spaceRegistryProxy.activeSpaceIds(_spaceId), 'Should not be active');
    assertTrue(handlerSpaceRegistry.ghost_isSpaceIdArchived(_spaceId), 'Ghost state should be archived');
    assertEq(handlerSpaceRegistry.ghost_totalArchives(), 1);
  }

  function test_handler_recoverSpaceId_eoa() public {
    address _actor = eoaActors[0];

    vm.prank(_actor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());
    bytes16 _spaceId = spaceRegistryProxy.addressToSpaceId(_actor);

    vm.prank(_actor);
    handlerSpaceRegistry.handler_archiveSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());
    assertTrue(spaceRegistryProxy.archivedSpaceIds(_spaceId), 'Should be archived');

    vm.prank(_actor);
    handlerSpaceRegistry.handler_recoverSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'recoverSpaceId should succeed');

    assertFalse(spaceRegistryProxy.archivedSpaceIds(_spaceId), 'Should not be archived');
    assertTrue(spaceRegistryProxy.registeredSpaceIds(_spaceId), 'Should still be registered');
    assertTrue(spaceRegistryProxy.activeSpaceIds(_spaceId), 'Should be active');
    assertFalse(handlerSpaceRegistry.ghost_isSpaceIdArchived(_spaceId), 'Ghost state should not be archived');
    assertEq(handlerSpaceRegistry.ghost_totalRecoveries(), 1);
  }

  function test_handler_clearSpaceId_eoa() public {
    address _actor = eoaActors[0];

    vm.prank(_actor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());
    bytes16 _spaceId = spaceRegistryProxy.addressToSpaceId(_actor);

    // Must archive before clearing
    vm.prank(_actor);
    handlerSpaceRegistry.handler_archiveSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());
    assertTrue(spaceRegistryProxy.archivedSpaceIds(_spaceId), 'Should be archived');

    vm.prank(_actor);
    handlerSpaceRegistry.handler_clearSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'clearSpaceId should succeed');

    assertEq(spaceRegistryProxy.addressToSpaceId(_actor), bytes16(0));
    assertEq(spaceRegistryProxy.spaceIdToAddress(_spaceId), address(0));
    assertFalse(spaceRegistryProxy.registeredSpaceIds(_spaceId));
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_spaceId));
    assertFalse(handlerSpaceRegistry.ghost_isAddressRegistered(_actor));
    assertFalse(handlerSpaceRegistry.ghost_isSpaceIdRegistered(_spaceId));
    assertFalse(
      handlerSpaceRegistry.ghost_isSpaceIdArchived(_spaceId), 'Ghost state should not be archived after clear'
    );
    assertEq(handlerSpaceRegistry.ghost_totalClears(), 1);
  }

  function test_handler_migration_flow() public {
    address _oldActor = eoaActors[0];
    address _newActor = eoaActors[1];

    vm.prank(_oldActor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());
    bytes16 _spaceId = spaceRegistryProxy.addressToSpaceId(_oldActor);

    vm.prank(_oldActor);
    handlerSpaceRegistry.handler_proposeSpaceMigration(1);
    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_spaceId), _newActor);

    vm.prank(_newActor);
    handlerSpaceRegistry.handler_acceptSpaceMigration();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'acceptSpaceMigration should succeed');

    assertEq(spaceRegistryProxy.addressToSpaceId(_oldActor), bytes16(0));
    assertEq(spaceRegistryProxy.addressToSpaceId(_newActor), _spaceId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_spaceId), _newActor);
    assertFalse(handlerSpaceRegistry.ghost_isAddressRegistered(_oldActor));
    assertTrue(handlerSpaceRegistry.ghost_isAddressRegistered(_newActor));
    assertEq(handlerSpaceRegistry.ghost_migrations(_oldActor), _newActor);
  }

  function test_handler_multiple_operations() public {
    for (uint256 _i = 0; _i < eoaActors.length; _i++) {
      vm.prank(eoaActors[_i]);
      handlerSpaceRegistry.handler_registerSpaceId();
      assertTrue(handlerSpaceRegistry.lastTxSucceeded());
    }
    assertEq(handlerSpaceRegistry.ghost_totalRegistrations(), eoaActors.length);

    // Archive before clearing
    vm.prank(eoaActors[1]);
    handlerSpaceRegistry.handler_archiveSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());
    assertEq(handlerSpaceRegistry.ghost_totalArchives(), 1);

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
    address _actor = eoaActors[0];

    vm.prank(_actor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());

    vm.prank(_actor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertFalse(handlerSpaceRegistry.lastTxSucceeded(), 'Duplicate should be skipped');
    assertEq(handlerSpaceRegistry.ghost_totalRegistrations(), 1);
  }

  function test_handler_archive_unregistered_skipped() public {
    vm.prank(eoaActors[0]);
    handlerSpaceRegistry.handler_archiveSpaceId();
    assertFalse(handlerSpaceRegistry.lastTxSucceeded(), 'Archive unregistered should be skipped');
  }

  function test_handler_recover_unregistered_skipped() public {
    vm.prank(eoaActors[0]);
    handlerSpaceRegistry.handler_recoverSpaceId();
    assertFalse(handlerSpaceRegistry.lastTxSucceeded(), 'Recover unregistered should be skipped');
  }

  function test_handler_recover_not_archived_skipped() public {
    address _actor = eoaActors[0];

    vm.prank(_actor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());

    vm.prank(_actor);
    handlerSpaceRegistry.handler_recoverSpaceId();
    assertFalse(handlerSpaceRegistry.lastTxSucceeded(), 'Recover not archived should be skipped');
  }

  function test_handler_clear_unregistered_skipped() public {
    vm.prank(eoaActors[0]);
    handlerSpaceRegistry.handler_clearSpaceId();
    assertFalse(handlerSpaceRegistry.lastTxSucceeded(), 'Clear unregistered should be skipped');
  }

  function test_handler_clear_not_archived_skipped() public {
    address _actor = eoaActors[0];

    vm.prank(_actor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());

    vm.prank(_actor);
    handlerSpaceRegistry.handler_clearSpaceId();
    assertFalse(handlerSpaceRegistry.lastTxSucceeded(), 'Clear not archived should be skipped');
  }

  function test_actor_type_detection() public view {
    for (uint256 _i = 0; _i < eoaActors.length; _i++) {
      assertTrue(handlerSpaceRegistry.isEOA(eoaActors[_i]), 'Should be EOA');
      assertFalse(handlerSpaceRegistry.isSpaceContract(eoaActors[_i]), 'Should not be Space');
    }

    for (uint256 _i = 0; _i < daoSpaceActors.length; _i++) {
      assertFalse(handlerSpaceRegistry.isEOA(daoSpaceActors[_i]), 'Should not be EOA');
      assertTrue(handlerSpaceRegistry.isDAOSpace(daoSpaceActors[_i]), 'Should be DAOSpace');
      assertTrue(handlerSpaceRegistry.isSpaceContract(daoSpaceActors[_i]), 'Should be Space');
    }

    for (uint256 _i = 0; _i < verifierSpaceActors.length; _i++) {
      assertFalse(handlerSpaceRegistry.isEOA(verifierSpaceActors[_i]), 'Should not be EOA');
      assertTrue(handlerSpaceRegistry.isVerifierSpace(verifierSpaceActors[_i]), 'Should be VerifierSpace');
      assertTrue(handlerSpaceRegistry.isSpaceContract(verifierSpaceActors[_i]), 'Should be Space');
    }
  }

  // ==================== DAOSpace Handler Tests ====================

  function test_handler_daoSpace_addEditor() public {
    address _newEditor = eoaActors[0];
    DAOSpace _dao = DAOSpace(daoSpaceActors[0]);

    vm.prank(_newEditor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'EOA registration should succeed');
    bytes16 _editorSpaceId = spaceRegistryProxy.addressToSpaceId(_newEditor);
    assertFalse(_dao.hasRole(_dao.EDITOR(), _editorSpaceId), 'Should not be editor yet');

    vm.prank(_newEditor);
    handlerDAOSpace.handler_daoSpace_addEditor(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'addEditor should succeed');
    assertTrue(_dao.hasRole(_dao.EDITOR(), _editorSpaceId), 'Should be editor now');
    assertEq(_dao.totalEditors(), 1, 'Should have 1 editor');
  }

  function test_handler_daoSpace_addMember() public {
    address _newMember = eoaActors[0];
    DAOSpace _dao = DAOSpace(daoSpaceActors[0]);

    vm.prank(_newMember);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());
    bytes16 _memberSpaceId = spaceRegistryProxy.addressToSpaceId(_newMember);
    assertFalse(_dao.hasRole(_dao.MEMBER(), _memberSpaceId), 'Should not be member yet');

    vm.prank(_newMember);
    handlerDAOSpace.handler_daoSpace_addMember(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'addMember should succeed');
    assertTrue(_dao.hasRole(_dao.MEMBER(), _memberSpaceId), 'Should be member now');
  }

  function test_handler_daoSpace_governance_flow() public {
    address _daoSpace = daoSpaceActors[0];
    address _editor = eoaActors[0];

    vm.prank(_editor);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded());

    vm.prank(_editor);
    handlerDAOSpace.handler_daoSpace_addEditor(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'addEditor should succeed');

    vm.prank(_editor);
    handlerDAOSpace.handler_daoSpace_createProposal(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'createProposal should succeed');
    assertEq(handlerDAOSpace.ghost_activeProposalsLength(_daoSpace), 1, 'Should have 1 proposal');

    vm.prank(_editor);
    handlerDAOSpace.handler_daoSpace_vote(0, 0, 1);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'vote should succeed');

    bytes16 _proposalId = handlerDAOSpace.ghost_activeProposals(_daoSpace, 0);
    assertEq(handlerDAOSpace.ghost_yesVotes(_proposalId), 1, 'Should have 1 yes vote');
  }

  function test_handler_daoSpace_createProposal_nonEditor_slowPath() public {
    address _member = eoaActors[0];

    vm.prank(_member);
    handlerSpaceRegistry.handler_registerSpaceId();

    vm.prank(_member);
    handlerDAOSpace.handler_daoSpace_addMember(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded());

    vm.prank(_member);
    handlerDAOSpace.handler_daoSpace_createProposal(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'Member should create slow path');

    vm.prank(_member);
    handlerDAOSpace.handler_daoSpace_createProposal(0, 1);
    assertTrue(
      handlerDAOSpace.lastTxSucceeded(), 'Member should create fast path (default: fast path allowed for new members)'
    );
  }

  // ==================== VerifierSpace Handler Tests ====================

  function test_handler_verifierSpace_enter() public {
    address _caller = eoaActors[0];
    VerifierSpace _vs = VerifierSpace(verifierSpaceActors[0]);

    vm.prank(_caller);
    handlerSpaceRegistry.handler_registerSpaceId();

    uint256 _nonceBefore = _vs.replayNonce();

    vm.prank(_caller);
    handlerVerifierSpace.handler_verifierSpace_enter(0, 0);
    assertTrue(handlerVerifierSpace.lastTxSucceeded(), 'enter should succeed');
    assertEq(_vs.replayNonce(), _nonceBefore + 1, 'Nonce should increase by 1');
    assertEq(handlerVerifierSpace.ghost_successfulVerifyCalls(), 1, 'Should have 1 successful call');
  }

  function test_handler_verifierSpace_replayAttack() public {
    address _caller = eoaActors[0];

    vm.prank(_caller);
    handlerSpaceRegistry.handler_registerSpaceId();

    vm.prank(_caller);
    handlerVerifierSpace.handler_verifierSpace_enter(0, 0);
    assertTrue(handlerVerifierSpace.lastTxSucceeded());

    vm.prank(_caller);
    handlerVerifierSpace.handler_verifierSpace_replayAttack(0);
    assertFalse(handlerVerifierSpace.lastTxSucceeded(), 'Replay attack should fail');
  }

  function test_handler_verifierSpace_multiple_enters() public {
    address _caller = eoaActors[0];
    VerifierSpace _vs = VerifierSpace(verifierSpaceActors[0]);

    vm.prank(_caller);
    handlerSpaceRegistry.handler_registerSpaceId();

    uint256 _initialNonce = _vs.replayNonce();

    for (uint256 _i = 0; _i < 3; _i++) {
      vm.prank(_caller);
      handlerVerifierSpace.handler_verifierSpace_enter(0, 0);
      assertTrue(handlerVerifierSpace.lastTxSucceeded(), 'Enter should succeed');
    }

    assertEq(_vs.replayNonce(), _initialNonce + 3, 'Nonce should increase by 3');
    assertEq(handlerVerifierSpace.ghost_successfulVerifyCalls(), 3, 'Should have 3 successful calls');
  }

  // ==================== Regression Tests ====================

  /// Deferred voting window: proposals stay open with zero timers until the first vote
  function test_regression_deferred_voting_window_until_first_vote() public {
    address _daoSpace = daoSpaceActors[0];
    address _voter = eoaActors[0];
    DAOSpace _dao = DAOSpace(_daoSpace);

    vm.prank(_voter);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'registration should succeed');

    vm.prank(_voter);
    handlerDAOSpace.handler_daoSpace_addEditor(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'addEditor should succeed');

    vm.prank(_voter);
    handlerDAOSpace.handler_daoSpace_createProposal(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'createProposal should succeed');

    bytes16 _proposalId = handlerDAOSpace.ghost_activeProposals(_daoSpace, 0);
    (,, IDAOSpace.ProposalParameters memory _params,,) = _dao.getLatestProposalInformation(_proposalId);
    assertEq(_params.startDate, 0, 'timers unset at creation');
    assertEq(_params.lastDate, 0, 'timers unset at creation');
    assertEq(_params.executeBy, 0, 'timers unset at creation');

    vm.warp(block.timestamp + 30 days);
    assertFalse(_dao.canExecuteProposal(_proposalId), 'cannot execute before voting window starts');

    vm.prank(_voter);
    handlerDAOSpace.handler_daoSpace_vote(0, 0, 1);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'first vote should succeed');

    (,, _params,,) = _dao.getLatestProposalInformation(_proposalId);
    assertGt(_params.startDate, 0, 'timers start on first vote');
    assertGt(_params.lastDate, _params.startDate, 'lastDate follows startDate');
    assertGt(_params.executeBy, _params.lastDate, 'executeBy follows lastDate');
  }

  /// Test the previously found H-0 "vote-migrate-vote again" vulnerability
  function test_regression_vote_migrate_vote_again() public {
    address _daoSpace = daoSpaceActors[0];
    address _voter1 = eoaActors[0];
    address _voter2 = eoaActors[1];
    DAOSpace _dao = DAOSpace(_daoSpace);

    // Register voter1 and make them an editor
    vm.prank(_voter1);
    handlerSpaceRegistry.handler_registerSpaceId();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'voter1 registration should succeed');

    vm.prank(_voter1);
    handlerDAOSpace.handler_daoSpace_addEditor(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'addEditor should succeed');

    // Create a proposal
    vm.prank(_voter1);
    handlerDAOSpace.handler_daoSpace_createProposal(0, 0);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'createProposal should succeed');

    bytes16 _proposalId = handlerDAOSpace.ghost_activeProposals(_daoSpace, 0);

    // First vote (Yes vote = option 1)
    vm.prank(_voter1);
    handlerDAOSpace.handler_daoSpace_vote(0, 0, 1);
    assertTrue(handlerDAOSpace.lastTxSucceeded(), 'First vote should succeed');

    // Get the spaceId before migration
    bytes16 _voterSpaceId = spaceRegistryProxy.addressToSpaceId(_voter1);

    // Check vote count after first vote
    (,,, IDAOSpace.Tally memory _tallyAfterFirst,) = _dao.getLatestProposalInformation(_proposalId);

    // Propose migration from voter1 to voter2
    vm.prank(_voter1);
    handlerSpaceRegistry.handler_proposeSpaceMigration(1); // 1 maps to voter2 (eoaActors[1])
    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'proposeSpaceMigration should succeed');

    // Accept migration as voter2
    vm.prank(_voter2);
    handlerSpaceRegistry.handler_acceptSpaceMigration();
    assertTrue(handlerSpaceRegistry.lastTxSucceeded(), 'acceptSpaceMigration should succeed');

    // Verify spaceId migrated
    assertEq(spaceRegistryProxy.addressToSpaceId(_voter2), _voterSpaceId, 'spaceId should have migrated');
    assertEq(spaceRegistryProxy.addressToSpaceId(_voter1), bytes16(0), 'voter1 should have no spaceId');

    // Try to vote again from the new address (voter2)
    vm.prank(_voter2);
    handlerDAOSpace.handler_daoSpace_vote(0, 0, 1);

    // The vulnerability would allow double voting - check that vote count hasn't increased
    (,,, IDAOSpace.Tally memory _tallyAfterSecond,) = _dao.getLatestProposalInformation(_proposalId);
    assertEq(
      _tallyAfterSecond.yes, _tallyAfterFirst.yes, 'Vote count should not increase after migration (no double voting)'
    );
  }
}
