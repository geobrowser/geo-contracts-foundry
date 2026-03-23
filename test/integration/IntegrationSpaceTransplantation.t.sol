// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';

import 'script/Constants.s.sol' as Constants;
import 'src/ActionsConstants.sol' as ActionsConstants;

contract IntegrationSpaceTransplantation is IntegrationBase {
  address internal _eoaSpaceBis;
  bytes16 internal _eoaSpaceBisId;

  function setUp() public override {
    IntegrationBase.setUp();
    vm.selectFork(_geoForkId);

    _eoaSpaceBis = makeAddr('eoaSpaceBis');
    vm.prank(_eoaSpaceBis);
    spaceRegistryProxy.registerSpaceId(keccak256('EOA_SPACE'), '1.0.0');
    _eoaSpaceBisId = spaceRegistryProxy.addressToSpaceId(_eoaSpaceBis);
  }

  function test_Transplantation_WhenDAOSpace() external {
    // 1. Create a new DAO space for transplantation
    bytes16 _transplantSpaceId = spaceRegistryProxy.generateSpaceId(address(0x1), 999);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_transplantSpaceId), address(0));

    vm.prank(Constants.GEO_GEO_MULTISIG_COUNCIL);
    DAOSpace _transplantProxy = DAOSpace(
      daoSpaceFactoryProxy.createDAOSpaceProxyForTransplant(
        _votingSettings, _initialSpaceEditors, _initialSpaceMembers, _transplantSpaceId
      )
    );

    assertEq(spaceRegistryProxy.addressToSpaceId(address(_transplantProxy)), bytes16(0));
    assertEq(spaceRegistryProxy.spaceIdToAddress(_transplantSpaceId), address(0));

    assertTrue(_transplantProxy.hasRole(daoSpaceImplementation.DAO(), _transplantSpaceId));
    assertTrue(_transplantProxy.hasRole(daoSpaceImplementation.MEMBER(), _initialSpaceMembers[0]));
    assertTrue(_transplantProxy.hasRole(daoSpaceImplementation.EDITOR(), _initialSpaceEditors[0]));

    // 2. Override SpaceId: bind the new proxy to the transplant space ID
    vm.prank(Constants.GEO_GEO_MULTISIG_COUNCIL);
    spaceRegistryProxy.overrideSpaceId(address(_transplantProxy), _transplantSpaceId);

    assertEq(spaceRegistryProxy.addressToSpaceId(address(_transplantProxy)), _transplantSpaceId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_transplantSpaceId), address(_transplantProxy));

    // 3. Override Actions: emit actions for indexer consistency
    bytes32[] memory _actions = new bytes32[](2);
    _actions[0] = ActionsConstants.EDITOR_ADDED;
    _actions[1] = ActionsConstants.MEMBER_ADDED;
    bytes32[] memory _subjects = new bytes32[](2);
    _subjects[0] = bytes32(_initialSpaceEditors[0]);
    _subjects[1] = bytes32(_initialSpaceMembers[0]);
    bytes[] memory _datas = new bytes[](2);
    _datas[0] = '';
    _datas[1] = '';

    bytes16[] memory _fromSpaceIds = new bytes16[](2);
    _fromSpaceIds[0] = _transplantSpaceId;
    _fromSpaceIds[1] = _transplantSpaceId;
    bytes16[] memory _toSpaceIds = new bytes16[](2);
    _toSpaceIds[0] = _transplantSpaceId;
    _toSpaceIds[1] = _transplantSpaceId;

    vm.expectEmit();
    emit ISpaceRegistry.Action(_transplantSpaceId, _transplantSpaceId, _actions[0], _subjects[0], _datas[0]);
    vm.expectEmit();
    emit ISpaceRegistry.Action(_transplantSpaceId, _transplantSpaceId, _actions[1], _subjects[1], _datas[1]);

    vm.prank(Constants.GEO_GEO_MULTISIG_COUNCIL);
    spaceRegistryProxy.overrideAction(_fromSpaceIds, _toSpaceIds, _actions, _subjects, _datas);

    // Transplanted space is usable: enter from existing space to transplant space
    bytes memory _createProposalData = abi.encode(bytes16(0), IDAOSpace.VotingMode.Slow, new IDAOSpace.Action[](0));
    vm.prank(eoaSpace);
    spaceRegistryProxy.enter(
      _eoaSpaceId, _transplantSpaceId, ActionsConstants.PROPOSAL_CREATED, '', _createProposalData, ''
    );
  }

  function test_Transplantation_WhenEOASpace() external {
    // 1. Override SpaceId: assign existing EOA space ID to another EOA
    assertEq(spaceRegistryProxy.addressToSpaceId(eoaSpace), _eoaSpaceId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_eoaSpaceId), eoaSpace);
    assertEq(spaceRegistryProxy.addressToSpaceId(_eoaSpaceBis), _eoaSpaceBisId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_eoaSpaceBisId), _eoaSpaceBis);

    vm.prank(Constants.GEO_GEO_MULTISIG_COUNCIL);
    spaceRegistryProxy.overrideSpaceId(_eoaSpaceBis, _eoaSpaceId);

    assertEq(spaceRegistryProxy.addressToSpaceId(_eoaSpaceBis), _eoaSpaceId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_eoaSpaceId), _eoaSpaceBis);
    assertEq(spaceRegistryProxy.addressToSpaceId(eoaSpace), bytes16(0));
    assertEq(spaceRegistryProxy.spaceIdToAddress(_eoaSpaceBisId), address(0));

    // 2. Override Actions: emit actions for indexer consistency
    bytes32[] memory _actions = new bytes32[](1);
    _actions[0] = ActionsConstants.EDITS_PUBLISHED;
    bytes32[] memory _subjects = new bytes32[](1);
    _subjects[0] = bytes32(keccak256('edits.topic'));
    bytes[] memory _datas = new bytes[](1);
    _datas[0] = abi.encode('ipfs://content', '1.0.0');

    bytes16[] memory _fromSpaceIds = new bytes16[](1);
    _fromSpaceIds[0] = _eoaSpaceId;
    bytes16[] memory _toSpaceIds = new bytes16[](1);
    _toSpaceIds[0] = _eoaSpaceId;

    vm.expectEmit();
    emit ISpaceRegistry.Action(_eoaSpaceId, _eoaSpaceId, _actions[0], _subjects[0], _datas[0]);

    vm.prank(Constants.GEO_GEO_MULTISIG_COUNCIL);
    spaceRegistryProxy.overrideAction(_fromSpaceIds, _toSpaceIds, _actions, _subjects, _datas);

    // Transplanted EOA space is usable: enter from overridden account to DAO space
    bytes memory _createProposalData = abi.encode(bytes16(0), IDAOSpace.VotingMode.Slow, new IDAOSpace.Action[](0));
    vm.prank(_eoaSpaceBis);
    spaceRegistryProxy.enter(
      _eoaSpaceId, _daoSpaceProxyId, ActionsConstants.PROPOSAL_CREATED, '', _createProposalData, ''
    );
  }
}
