// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';

import 'src/ActionsConstants.sol' as ActionsConstants;

contract IntegrationSpaceMigration is IntegrationBase {
  // Spaces
  address public eoaSpaceBis = makeAddr('eoaSpaceBis');
  address public eoaSpaceTer = makeAddr('eoaSpaceTer');
  DAOSpace public daoSpaceProxyBis;
  VerifierSpace public verifierSpaceProxyBis;

  // Space IDs
  bytes16 internal _eoaSpaceBisId;
  bytes16 internal _daoSpaceProxyBisId;
  bytes16 internal _verifierSpaceProxyBisId;

  // Space settings
  address[] internal _initialSpaceEditorsBis;
  address[] internal _initialSpaceMembersBis;

  function setUp() public override {
    IntegrationBase.setUp();
    vm.selectFork(_geoTestnetForkId);

    vm.prank(eoaSpaceBis);
    spaceRegistryProxy.registerSpaceId(keccak256('EOA_SPACE'), '1.0.0');
    _eoaSpaceBisId = spaceRegistryProxy.addressToSpaceId(eoaSpaceBis);

    _initialSpaceEditorsBis = new address[](1);
    _initialSpaceEditorsBis[0] = eoaSpaceBis;
    _initialSpaceMembersBis = new address[](1);
    _initialSpaceMembersBis[0] = eoaSpaceBis;

    daoSpaceProxyBis = DAOSpace(
      daoSpaceFactoryProxy.createDAOSpaceProxy(
        _votingSettings,
        _initialSpaceEditorsBis,
        _initialSpaceMembersBis,
        _initialEditsContentUri,
        _initialEditsMetadata
      )
    );
    _daoSpaceProxyBisId = spaceRegistryProxy.addressToSpaceId(address(daoSpaceProxyBis));

    verifierSpaceProxyBis = VerifierSpace(verifierSpaceFactoryProxy.createVerifierSpaceProxy(eoaSpaceBis));
    _verifierSpaceProxyBisId = spaceRegistryProxy.addressToSpaceId(address(verifierSpaceProxyBis));
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

  function test_SpaceMigration_DAOSpace() external {
    // daoSpaceProxy
    assertEq(spaceRegistryProxy.addressToSpaceId(address(daoSpaceProxy)), _daoSpaceProxyId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_daoSpaceProxyId), address(daoSpaceProxy));
    // daoSpaceProxyBis
    assertEq(spaceRegistryProxy.addressToSpaceId(address(daoSpaceProxyBis)), _daoSpaceProxyBisId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_daoSpaceProxyBisId), address(daoSpaceProxyBis));

    // daoSpaceProxy
    // Proposal 0 (slow path): proposeSpaceMigration();
    bytes16 _proposalId = 0;
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(spaceRegistryProxy),
      value: 0,
      data: abi.encodeCall(ISpaceRegistry.proposeSpaceMigration, (address(daoSpaceProxyBis)))
    });
    bytes memory _createProposalData = abi.encode(_proposalId, IDAOSpace.VotingMode.Slow, _actions);
    bytes memory _voteProposalData = abi.encode(_proposalId, IDAOSpace.VoteOption.Yes);
    bytes memory _executeProposalData = abi.encode(_proposalId);

    vm.startPrank(eoaSpace);
    // PROPOSAL_CREATED
    spaceRegistryProxy.enter(
      eoaSpace, address(daoSpaceProxy), ActionsConstants.PROPOSAL_CREATED, '', _createProposalData, ''
    );
    // PROPOSAL_VOTED
    spaceRegistryProxy.enter(
      eoaSpace, address(daoSpaceProxy), ActionsConstants.PROPOSAL_VOTED, '', _voteProposalData, ''
    );
    // PROPOSAL_EXECUTED
    skip(daoSpaceImplementation.MINIMUM_VOTING_DURATION() + 1);
    spaceRegistryProxy.enter(
      eoaSpace, address(daoSpaceProxy), ActionsConstants.PROPOSAL_EXECUTED, '', _executeProposalData, ''
    );
    vm.stopPrank();

    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_daoSpaceProxyId), address(daoSpaceProxyBis));

    // daoSpaceProxyBis
    // Proposal 0 (slow path): clearSpaceId(); acceptSpaceMigration();
    _proposalId = 0;
    _actions = new IDAOSpace.Action[](2);
    _actions[0] = IDAOSpace.Action({
      to: address(spaceRegistryProxy), value: 0, data: abi.encodeCall(ISpaceRegistry.clearSpaceId, ())
    });
    _actions[1] = IDAOSpace.Action({
      to: address(spaceRegistryProxy),
      value: 0,
      data: abi.encodeCall(ISpaceRegistry.acceptSpaceMigration, (_daoSpaceProxyId, 'DAO_SPACE', '1.0.0'))
    });
    _createProposalData = abi.encode(_proposalId, IDAOSpace.VotingMode.Slow, _actions);
    _voteProposalData = abi.encode(_proposalId, IDAOSpace.VoteOption.Yes);
    _executeProposalData = abi.encode(_proposalId);

    vm.startPrank(eoaSpaceBis);
    // PROPOSAL_CREATED
    spaceRegistryProxy.enter(
      eoaSpaceBis, address(daoSpaceProxyBis), ActionsConstants.PROPOSAL_CREATED, '', _createProposalData, ''
    );
    // PROPOSAL_VOTED
    spaceRegistryProxy.enter(
      eoaSpaceBis, address(daoSpaceProxyBis), ActionsConstants.PROPOSAL_VOTED, '', _voteProposalData, ''
    );
    // PROPOSAL_EXECUTED
    skip(daoSpaceImplementation.MINIMUM_VOTING_DURATION() + 1);
    spaceRegistryProxy.enter(
      eoaSpaceBis, address(daoSpaceProxyBis), ActionsConstants.PROPOSAL_EXECUTED, '', _executeProposalData, ''
    );
    vm.stopPrank();

    assertEq(spaceRegistryProxy.addressToSpaceId(address(daoSpaceProxy)), bytes16(0));
    assertEq(spaceRegistryProxy.addressToSpaceId(address(daoSpaceProxyBis)), _daoSpaceProxyId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_daoSpaceProxyId), address(daoSpaceProxyBis));
    assertEq(spaceRegistryProxy.spaceIdToAddress(_daoSpaceProxyBisId), address(0));
    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_daoSpaceProxyId), address(0));
  }

  function test_SpaceMigration_VerifierSpace() external {
    // verifierSpaceProxy
    assertEq(spaceRegistryProxy.addressToSpaceId(address(verifierSpaceProxy)), _verifierSpaceProxyId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_verifierSpaceProxyId), address(verifierSpaceProxy));
    // verifierSpaceProxyBis
    assertEq(spaceRegistryProxy.addressToSpaceId(address(verifierSpaceProxyBis)), _verifierSpaceProxyBisId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_verifierSpaceProxyBisId), address(verifierSpaceProxyBis));

    vm.prank(eoaSpace);
    verifierSpaceProxy.proposeMigration(address(verifierSpaceProxyBis));

    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_verifierSpaceProxyId), address(verifierSpaceProxyBis));

    vm.expectRevert(ISpaceRegistry.SpaceAlreadyRegistered.selector);
    vm.prank(eoaSpaceBis);
    verifierSpaceProxyBis.acceptMigration(_verifierSpaceProxyId);

    vm.startPrank(eoaSpaceBis);
    verifierSpaceProxyBis.clear();
    verifierSpaceProxyBis.acceptMigration(_verifierSpaceProxyId);
    vm.stopPrank();

    assertEq(spaceRegistryProxy.addressToSpaceId(address(verifierSpaceProxy)), bytes16(0));
    assertEq(spaceRegistryProxy.addressToSpaceId(address(verifierSpaceProxyBis)), _verifierSpaceProxyId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_verifierSpaceProxyId), address(verifierSpaceProxyBis));
    assertEq(spaceRegistryProxy.spaceIdToAddress(_verifierSpaceProxyBisId), address(0));
    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_verifierSpaceProxyId), address(0));
  }
}
