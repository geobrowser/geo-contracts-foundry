// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {MockDAOSpaceV2} from 'test/integration/mocks/MockDAOSpaceV2.sol';
import {MockNewImplementation} from 'test/integration/mocks/MockNewImplementation.sol';

import 'script/Constants.s.sol' as Constants;

contract IntegrationUpgradeBeaconImplementation is IntegrationBase {
  // Spaces
  MockDAOSpaceV2 public daoSpaceImplementationBis;
  MockDAOSpaceV2 public daoSpaceProxyA;
  MockDAOSpaceV2 public daoSpaceProxyB;

  VerifierSpace public verifierSpaceImplementationBis;
  VerifierSpace public verifierSpaceProxyA;
  VerifierSpace public verifierSpaceProxyB;

  // Space IDs
  bytes16 internal _daoSpaceProxyAId;
  bytes16 internal _daoSpaceProxyBId;
  bytes16 internal _verifierSpaceProxyAId;
  bytes16 internal _verifierSpaceProxyBId;

  function setUp() public override {
    IntegrationBase.setUp();
    vm.selectFork(_geoForkId);

    daoSpaceProxyA = MockDAOSpaceV2(address(daoSpaceProxy));
    daoSpaceProxyB = MockDAOSpaceV2(
      daoSpaceFactoryProxy.createDAOSpaceProxy(
        _votingSettings,
        _initialSpaceEditors,
        _initialSpaceMembers,
        _initialEditsContentUri,
        _initialEditsMetadata,
        _initialTopicId
      )
    );
    _daoSpaceProxyAId = _daoSpaceProxyId;
    _daoSpaceProxyBId = spaceRegistryProxy.addressToSpaceId(address(daoSpaceProxyB));

    verifierSpaceProxyA = verifierSpaceProxy;
    verifierSpaceProxyB = VerifierSpace(verifierSpaceFactoryProxy.createVerifierSpaceProxy(eoaSpace));
    _verifierSpaceProxyAId = _verifierSpaceProxyId;
    _verifierSpaceProxyBId = spaceRegistryProxy.addressToSpaceId(address(verifierSpaceProxyB));

    daoSpaceImplementationBis = new MockDAOSpaceV2();
    verifierSpaceImplementationBis = VerifierSpace(address(new MockNewImplementation()));
  }

  function test_UpgradeBeaconImplementation_DAOSpace() external {
    assertEq(daoSpaceBeacon.implementation(), address(daoSpaceImplementation));
    assertEq(daoSpaceImplementation.version(), '1.0.0');
    assertEq(daoSpaceProxyA.version(), '1.0.0');
    assertEq(daoSpaceProxyB.version(), '1.0.0');
    // _initialMembers
    assertTrue(daoSpaceProxyA.hasRole(daoSpaceImplementation.MEMBER(), _eoaSpaceId));
    assertTrue(daoSpaceProxyB.hasRole(daoSpaceImplementation.MEMBER(), _eoaSpaceId));
    // actionIsFastPathValid
    assertTrue(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.addMember.selector));
    assertTrue(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.addMember.selector));
    assertTrue(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.removeMember.selector));
    assertTrue(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.removeMember.selector));
    assertFalse(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.addEditor.selector));
    assertFalse(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.addEditor.selector));
    assertFalse(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.removeEditor.selector));
    assertFalse(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.removeEditor.selector));

    vm.prank(Constants.GEO_GEO_MULTISIG_COUNCIL);
    daoSpaceBeacon.upgradeTo(address(daoSpaceImplementationBis));

    uint256 _initialTotalMembers = _initialSpaceMembers.length;
    daoSpaceProxyA.initialize(abi.encode(_initialTotalMembers));
    daoSpaceProxyB.initialize(abi.encode(_initialTotalMembers));

    vm.prank(address(daoSpaceProxyA));
    daoSpaceProxyA.addMember(_daoSpaceProxyAId);
    vm.prank(address(daoSpaceProxyB));
    daoSpaceProxyB.addMember(_daoSpaceProxyBId);

    assertEq(daoSpaceBeacon.implementation(), address(daoSpaceImplementationBis));
    assertEq(daoSpaceImplementationBis.version(), '2.0.0');
    assertEq(daoSpaceProxyA.version(), '2.0.0');
    assertEq(daoSpaceProxyB.version(), '2.0.0');
    // totalMembers
    assertEq(daoSpaceProxyA.totalMembers(), _initialTotalMembers + 1);
    assertEq(daoSpaceProxyB.totalMembers(), _initialTotalMembers + 1);
    // actionIsFastPathValid
    assertFalse(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.addMember.selector));
    assertFalse(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.addMember.selector));
    assertFalse(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.removeMember.selector));
    assertFalse(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.removeMember.selector));
    assertTrue(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.addEditor.selector));
    assertTrue(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.addEditor.selector));
    assertTrue(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.removeEditor.selector));
    assertTrue(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.removeEditor.selector));
  }

  function test_UpgradeBeaconImplementation_VerifierSpace() external {
    assertEq(verifierSpaceBeacon.implementation(), address(verifierSpaceImplementation));
    assertEq(verifierSpaceImplementation.version(), '1.0.0');
    assertEq(verifierSpaceProxyA.version(), '1.0.0');
    assertEq(verifierSpaceProxyB.version(), '1.0.0');

    vm.prank(Constants.GEO_GEO_MULTISIG_COUNCIL);
    verifierSpaceBeacon.upgradeTo(address(verifierSpaceImplementationBis));

    assertEq(verifierSpaceBeacon.implementation(), address(verifierSpaceImplementationBis));
    assertEq(verifierSpaceImplementationBis.version(), '2.0.0');
    assertEq(verifierSpaceProxyA.version(), '2.0.0');
    assertEq(verifierSpaceProxyB.version(), '2.0.0');
  }
}
