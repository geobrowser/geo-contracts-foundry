// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {MockMigratableVerifierSpace} from 'test/integration/mocks/MockMigratableVerifierSpace.sol';

import 'script/Constants.s.sol' as Constants;
import 'src/ActionsConstants.sol' as ActionsConstants;

contract IntegrationSpaceMigration is IntegrationBase {
  // Spaces
  address public eoaSpaceBis = makeAddr('eoaSpaceBis');
  address public eoaSpaceTer = makeAddr('eoaSpaceTer');
  DAOSpace public daoSpaceProxyBis;
  VerifierSpace public verifierSpaceProxyBis;
  MockMigratableVerifierSpace public migratableVerifierSpaceImplementation;

  // Space IDs
  bytes16 internal _eoaSpaceBisId;
  bytes16 internal _daoSpaceProxyBisId;
  bytes16 internal _verifierSpaceProxyBisId;

  // Space settings
  bytes16[] internal _initialSpaceEditorsBis;
  bytes16[] internal _initialSpaceMembersBis;

  // Proposals
  bytes16 internal _proposalId;
  uint8 internal _proposalVersion = 1;

  function setUp() public override {
    IntegrationBase.setUp();
    vm.selectFork(_geoForkId);

    vm.prank(eoaSpaceBis);
    spaceRegistryProxy.registerSpaceId(keccak256('EOA_SPACE'), '1.0.0');
    _eoaSpaceBisId = spaceRegistryProxy.addressToSpaceId(eoaSpaceBis);

    _initialSpaceEditorsBis = new bytes16[](1);
    _initialSpaceEditorsBis[0] = _eoaSpaceBisId;
    _initialSpaceMembersBis = new bytes16[](1);
    _initialSpaceMembersBis[0] = _eoaSpaceBisId;

    daoSpaceProxyBis = DAOSpace(
      daoSpaceFactoryProxy.createDAOSpaceProxy(
        _votingSettings,
        _initialSpaceEditorsBis,
        _initialSpaceMembersBis,
        _initialEditsContentUri,
        _initialEditsMetadata,
        _initialTopicId
      )
    );
    _daoSpaceProxyBisId = spaceRegistryProxy.addressToSpaceId(address(daoSpaceProxyBis));

    verifierSpaceProxyBis = VerifierSpace(verifierSpaceFactoryProxy.createVerifierSpaceProxy(eoaSpaceBis));
    _verifierSpaceProxyBisId = spaceRegistryProxy.addressToSpaceId(address(verifierSpaceProxyBis));

    migratableVerifierSpaceImplementation = new MockMigratableVerifierSpace();
    vm.prank(Constants.GEO_GEO_MULTISIG_COUNCIL);
    verifierSpaceBeacon.upgradeTo(address(migratableVerifierSpaceImplementation));
  }

  function test_SpaceMigration_EOASpace() external {
    // eoaSpace
    assertEq(spaceRegistryProxy.addressToSpaceId(eoaSpace), _eoaSpaceId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_eoaSpaceId), eoaSpace);
    // eoaSpaceTer
    assertEq(spaceRegistryProxy.addressToSpaceId(eoaSpaceTer), bytes16(0));

    vm.prank(eoaSpace);
    spaceRegistryProxy.proposeSpaceMigration(eoaSpaceTer);

    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_eoaSpaceId), eoaSpaceTer);

    vm.expectRevert(ISpaceRegistry.InvalidCaller.selector);
    vm.prank(eoaSpace);
    spaceRegistryProxy.acceptSpaceMigration(_eoaSpaceId, keccak256('EOA_SPACE'), '1.0.0');

    vm.prank(eoaSpaceTer);
    spaceRegistryProxy.acceptSpaceMigration(_eoaSpaceId, keccak256('EOA_SPACE'), '1.0.0');

    assertEq(spaceRegistryProxy.addressToSpaceId(eoaSpace), bytes16(0));
    assertEq(spaceRegistryProxy.addressToSpaceId(eoaSpaceTer), _eoaSpaceId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_eoaSpaceId), eoaSpaceTer);
    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_eoaSpaceId), address(0));
  }

  function test_SpaceMigration_EOASpace_DAOSpaceMultiVote() external {
    // daoSpaceProxy
    // Proposal 0 (slow path): archiveSpaceId(); clearSpaceId();
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](2);
    _actions[0] = IDAOSpace.Action({
      to: address(spaceRegistryProxy), value: 0, data: abi.encodeCall(ISpaceRegistry.archiveSpaceId, ())
    });
    _actions[1] = IDAOSpace.Action({
      to: address(spaceRegistryProxy), value: 0, data: abi.encodeCall(ISpaceRegistry.clearSpaceId, ())
    });
    bytes memory _createProposalData = abi.encode(_proposalId, IDAOSpace.VotingMode.Slow, _actions);
    bytes memory _voteProposalData = abi.encode(_proposalId, _proposalVersion, IDAOSpace.VoteOption.Yes);

    vm.startPrank(eoaSpace);
    // PROPOSAL_CREATED
    spaceRegistryProxy.enter(
      _eoaSpaceId, _daoSpaceProxyId, ActionsConstants.PROPOSAL_CREATED, '', _createProposalData, ''
    );
    // PROPOSAL_VOTED
    spaceRegistryProxy.enter(_eoaSpaceId, _daoSpaceProxyId, ActionsConstants.PROPOSAL_VOTED, '', _voteProposalData, '');
    // MIGRATION_PROPOSED
    spaceRegistryProxy.proposeSpaceMigration(eoaSpaceTer);
    vm.stopPrank();

    (,,, IDAOSpace.Tally memory _tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(_tally.yes, 1);

    // Before migration, eoaSpace should be active
    assertTrue(spaceRegistryProxy.registeredSpaceIds(_eoaSpaceId));
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_eoaSpaceId));
    assertTrue(spaceRegistryProxy.activeSpaceIds(_eoaSpaceId));

    vm.startPrank(eoaSpaceTer);
    // MIGRATION_ACCEPTED
    spaceRegistryProxy.acceptSpaceMigration(_eoaSpaceId, keccak256('EOA_SPACE'), '1.0.0');
    // PROPOSAL_VOTED
    spaceRegistryProxy.enter(_eoaSpaceId, _daoSpaceProxyId, ActionsConstants.PROPOSAL_VOTED, '', _voteProposalData, '');
    vm.stopPrank();

    (,,, _tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(_tally.yes, 1);

    // After migration, eoaSpaceTer should be active
    assertTrue(spaceRegistryProxy.registeredSpaceIds(_eoaSpaceId));
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_eoaSpaceId));
    assertTrue(spaceRegistryProxy.activeSpaceIds(_eoaSpaceId));
  }

  function test_SpaceMigration_DAOSpace() external {
    // daoSpaceProxy
    assertEq(spaceRegistryProxy.addressToSpaceId(address(daoSpaceProxy)), _daoSpaceProxyId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_daoSpaceProxyId), address(daoSpaceProxy));
    // daoSpaceProxyBis
    assertEq(spaceRegistryProxy.addressToSpaceId(address(daoSpaceProxyBis)), _daoSpaceProxyBisId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_daoSpaceProxyBisId), address(daoSpaceProxyBis));

    // daoSpaceProxy
    // Proposal 0 (slow path): proposeSpaceMigration();
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(spaceRegistryProxy),
      value: 0,
      data: abi.encodeCall(ISpaceRegistry.proposeSpaceMigration, (address(daoSpaceProxyBis)))
    });
    bytes memory _createProposalData = abi.encode(_proposalId, IDAOSpace.VotingMode.Slow, _actions);
    bytes memory _voteProposalData = abi.encode(_proposalId, _proposalVersion, IDAOSpace.VoteOption.Yes);
    bytes memory _executeProposalData = abi.encode(_proposalId);

    vm.startPrank(eoaSpace);
    // PROPOSAL_CREATED
    spaceRegistryProxy.enter(
      _eoaSpaceId, _daoSpaceProxyId, ActionsConstants.PROPOSAL_CREATED, '', _createProposalData, ''
    );
    // PROPOSAL_VOTED
    spaceRegistryProxy.enter(_eoaSpaceId, _daoSpaceProxyId, ActionsConstants.PROPOSAL_VOTED, '', _voteProposalData, '');
    skip(daoSpaceImplementation.MINIMUM_VOTING_DURATION() + 1);
    // PROPOSAL_EXECUTED
    spaceRegistryProxy.enter(
      _eoaSpaceId, _daoSpaceProxyId, ActionsConstants.PROPOSAL_EXECUTED, '', _executeProposalData, ''
    );
    vm.stopPrank();

    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_daoSpaceProxyId), address(daoSpaceProxyBis));

    // Before migration, daoSpaceProxyBis should be active
    assertTrue(spaceRegistryProxy.registeredSpaceIds(_daoSpaceProxyBisId));
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_daoSpaceProxyBisId));
    assertTrue(spaceRegistryProxy.activeSpaceIds(_daoSpaceProxyBisId));

    // daoSpaceProxyBis
    // Proposal 0 (slow path): archiveSpaceId(); clearSpaceId(); acceptSpaceMigration();
    _actions = new IDAOSpace.Action[](3);
    _actions[0] = IDAOSpace.Action({
      to: address(spaceRegistryProxy), value: 0, data: abi.encodeCall(ISpaceRegistry.archiveSpaceId, ())
    });
    _actions[1] = IDAOSpace.Action({
      to: address(spaceRegistryProxy), value: 0, data: abi.encodeCall(ISpaceRegistry.clearSpaceId, ())
    });
    _actions[2] = IDAOSpace.Action({
      to: address(spaceRegistryProxy),
      value: 0,
      data: abi.encodeCall(ISpaceRegistry.acceptSpaceMigration, (_daoSpaceProxyId, 'DAO_SPACE', '1.0.0'))
    });
    _createProposalData = abi.encode(_proposalId, IDAOSpace.VotingMode.Slow, _actions);
    _voteProposalData = abi.encode(_proposalId, _proposalVersion, IDAOSpace.VoteOption.Yes);
    _executeProposalData = abi.encode(_proposalId);

    vm.startPrank(eoaSpaceBis);
    // PROPOSAL_CREATED
    spaceRegistryProxy.enter(
      _eoaSpaceBisId, _daoSpaceProxyBisId, ActionsConstants.PROPOSAL_CREATED, '', _createProposalData, ''
    );
    // PROPOSAL_VOTED
    spaceRegistryProxy.enter(
      _eoaSpaceBisId, _daoSpaceProxyBisId, ActionsConstants.PROPOSAL_VOTED, '', _voteProposalData, ''
    );
    skip(daoSpaceImplementation.MINIMUM_VOTING_DURATION() + 1);
    // PROPOSAL_EXECUTED
    spaceRegistryProxy.enter(
      _eoaSpaceBisId, _daoSpaceProxyBisId, ActionsConstants.PROPOSAL_EXECUTED, '', _executeProposalData, ''
    );
    vm.stopPrank();

    assertEq(spaceRegistryProxy.addressToSpaceId(address(daoSpaceProxy)), bytes16(0));
    assertEq(spaceRegistryProxy.addressToSpaceId(address(daoSpaceProxyBis)), _daoSpaceProxyId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_daoSpaceProxyId), address(daoSpaceProxyBis));
    assertEq(spaceRegistryProxy.spaceIdToAddress(_daoSpaceProxyBisId), address(0));
    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_daoSpaceProxyId), address(0));

    // After migration, _daoSpaceProxyId (migrated spaceId) should be active with daoSpaceProxyBis
    assertTrue(spaceRegistryProxy.registeredSpaceIds(_daoSpaceProxyId));
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_daoSpaceProxyId));
    assertTrue(spaceRegistryProxy.activeSpaceIds(_daoSpaceProxyId));

    // daoSpaceProxyBisId should be cleared (daoSpaceProxyBis cleared itself before accepting migration)
    assertFalse(spaceRegistryProxy.registeredSpaceIds(_daoSpaceProxyBisId));
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_daoSpaceProxyBisId));
    assertFalse(spaceRegistryProxy.activeSpaceIds(_daoSpaceProxyBisId));
  }

  function test_SpaceMigration_VerifierSpace() external {
    // verifierSpaceProxy
    assertEq(spaceRegistryProxy.addressToSpaceId(address(verifierSpaceProxy)), _verifierSpaceProxyId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_verifierSpaceProxyId), address(verifierSpaceProxy));
    // verifierSpaceProxyBis
    assertEq(spaceRegistryProxy.addressToSpaceId(address(verifierSpaceProxyBis)), _verifierSpaceProxyBisId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_verifierSpaceProxyBisId), address(verifierSpaceProxyBis));

    vm.prank(eoaSpace);
    MockMigratableVerifierSpace(address(verifierSpaceProxy)).proposeMigration(address(verifierSpaceProxyBis));

    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_verifierSpaceProxyId), address(verifierSpaceProxyBis));

    vm.expectRevert(ISpaceRegistry.SpaceAlreadyRegistered.selector);
    vm.prank(eoaSpaceBis);
    MockMigratableVerifierSpace(address(verifierSpaceProxyBis)).acceptMigration(_verifierSpaceProxyId);

    // Before archiving, verifierSpaceProxyBis should be active
    assertTrue(spaceRegistryProxy.registeredSpaceIds(_verifierSpaceProxyBisId));
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_verifierSpaceProxyBisId));
    assertTrue(spaceRegistryProxy.activeSpaceIds(_verifierSpaceProxyBisId));

    vm.startPrank(eoaSpaceBis);
    MockMigratableVerifierSpace(address(verifierSpaceProxyBis)).archive();
    // After archiving, verifierSpaceProxyBis should be archived
    assertTrue(spaceRegistryProxy.registeredSpaceIds(_verifierSpaceProxyBisId));
    assertTrue(spaceRegistryProxy.archivedSpaceIds(_verifierSpaceProxyBisId));
    assertFalse(spaceRegistryProxy.activeSpaceIds(_verifierSpaceProxyBisId));

    MockMigratableVerifierSpace(address(verifierSpaceProxyBis)).clear();
    // After clearing, verifierSpaceProxyBis should be cleared
    assertFalse(spaceRegistryProxy.registeredSpaceIds(_verifierSpaceProxyBisId));
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_verifierSpaceProxyBisId));
    assertFalse(spaceRegistryProxy.activeSpaceIds(_verifierSpaceProxyBisId));

    MockMigratableVerifierSpace(address(verifierSpaceProxyBis)).acceptMigration(_verifierSpaceProxyId);
    vm.stopPrank();

    assertEq(spaceRegistryProxy.addressToSpaceId(address(verifierSpaceProxy)), bytes16(0));
    assertEq(spaceRegistryProxy.addressToSpaceId(address(verifierSpaceProxyBis)), _verifierSpaceProxyId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_verifierSpaceProxyId), address(verifierSpaceProxyBis));
    assertEq(spaceRegistryProxy.spaceIdToAddress(_verifierSpaceProxyBisId), address(0));
    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_verifierSpaceProxyId), address(0));

    // After migration, _verifierSpaceProxyId (migrated spaceId) should be active with verifierSpaceProxyBis
    assertTrue(spaceRegistryProxy.registeredSpaceIds(_verifierSpaceProxyId));
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_verifierSpaceProxyId));
    assertTrue(spaceRegistryProxy.activeSpaceIds(_verifierSpaceProxyId));

    // verifierSpaceProxyBisId should be cleared (verifierSpaceProxyBis cleared itself before accepting migration)
    assertFalse(spaceRegistryProxy.registeredSpaceIds(_verifierSpaceProxyBisId));
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_verifierSpaceProxyBisId));
    assertFalse(spaceRegistryProxy.activeSpaceIds(_verifierSpaceProxyBisId));
  }
}
