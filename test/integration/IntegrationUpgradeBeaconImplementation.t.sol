// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {MockDAOSpaceV2} from 'test/integration/mocks/MockDAOSpaceV2.sol';
import {MockNewImplementation} from 'test/integration/mocks/MockNewImplementation.sol';

import 'script/Constants.s.sol' as Constants;

contract IntegrationUpgradeBeaconImplementation is IntegrationBase {
  UpgradeableBeacon public daoSpaceBeacon;
  DAOSpace public daoSpaceImplementationA;
  MockDAOSpaceV2 public daoSpaceImplementationB;
  MockDAOSpaceV2 public daoSpaceProxyA;
  MockDAOSpaceV2 public daoSpaceProxyB;

  UpgradeableBeacon public verifierSpaceBeacon;
  VerifierSpace public verifierSpaceImplementationA;
  VerifierSpace public verifierSpaceImplementationB;
  VerifierSpace public verifierSpaceProxyA;
  VerifierSpace public verifierSpaceProxyB;

  function setUp() public override {
    IntegrationBase.setUp();
    vm.selectFork(_geoTestnetForkId);

    daoSpaceBeacon = UpgradeableBeacon(daoSpaceFactoryProxy.daoSpaceBeacon());
    verifierSpaceBeacon = UpgradeableBeacon(verifierSpaceFactoryProxy.verifierSpaceBeacon());

    daoSpaceImplementationA = DAOSpace(daoSpaceBeacon.implementation());
    verifierSpaceImplementationA = VerifierSpace(verifierSpaceBeacon.implementation());

    _votingSettings.duration = daoSpaceImplementationA.MINIMUM_VOTING_DURATION();

    // Register this address as a space and get its space ID
    spaceRegistryProxy.registerSpaceId(keccak256('EOA_SPACE'), abi.encode('1.0.0'));
    bytes16 thisSpaceId = spaceRegistryProxy.addressToSpaceId(address(this));

    _initialSpaceMembers = new bytes16[](1);
    _initialSpaceMembers[0] = thisSpaceId;
    _initialSpaceOwner = address(this);

    daoSpaceProxyA = MockDAOSpaceV2(
      daoSpaceFactoryProxy.createDAOSpaceProxy(
        _votingSettings, _initialSpaceEditors, _initialSpaceMembers, _initialEditsContentUri, _initialEditsMetadata
      )
    );
    daoSpaceProxyB = MockDAOSpaceV2(
      daoSpaceFactoryProxy.createDAOSpaceProxy(
        _votingSettings, _initialSpaceEditors, _initialSpaceMembers, _initialEditsContentUri, _initialEditsMetadata
      )
    );
    verifierSpaceProxyA = VerifierSpace(verifierSpaceFactoryProxy.createVerifierSpaceProxy(_initialSpaceOwner));
    verifierSpaceProxyB = VerifierSpace(verifierSpaceFactoryProxy.createVerifierSpaceProxy(_initialSpaceOwner));

    daoSpaceImplementationB = new MockDAOSpaceV2();
    verifierSpaceImplementationB = VerifierSpace(address(new MockNewImplementation()));
  }

  function test_UpgradeBeaconImplementation_DAOSpace() external {
    assertEq(daoSpaceBeacon.implementation(), address(daoSpaceImplementationA));
    assertEq(daoSpaceImplementationA.version(), '1.0.0');
    assertEq(daoSpaceProxyA.version(), '1.0.0');
    assertEq(daoSpaceProxyB.version(), '1.0.0');
    // _initialMembers
    bytes16 thisSpaceId = spaceRegistryProxy.addressToSpaceId(address(this));
    assertTrue(daoSpaceProxyA.hasRole(daoSpaceProxyA.MEMBER(), thisSpaceId));
    assertTrue(daoSpaceProxyB.hasRole(daoSpaceProxyB.MEMBER(), thisSpaceId));
    // actionIsFastPathValid
    assertTrue(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.addMember.selector));
    assertTrue(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.addMember.selector));
    assertTrue(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.removeMember.selector));
    assertTrue(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.removeMember.selector));
    assertFalse(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.addEditor.selector));
    assertFalse(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.addEditor.selector));
    assertFalse(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.removeEditor.selector));
    assertFalse(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.removeEditor.selector));

    vm.prank(Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL);
    daoSpaceBeacon.upgradeTo(address(daoSpaceImplementationB));

    uint256 _initialTotalMembers = _initialSpaceMembers.length;
    daoSpaceProxyA.initialize(abi.encode(_initialTotalMembers));
    daoSpaceProxyB.initialize(abi.encode(_initialTotalMembers));

    bytes16 daoSpaceProxyASpaceId = spaceRegistryProxy.addressToSpaceId(address(daoSpaceProxyA));
    bytes16 daoSpaceProxyBSpaceId = spaceRegistryProxy.addressToSpaceId(address(daoSpaceProxyB));
    vm.prank(address(daoSpaceProxyA));
    daoSpaceProxyA.addMember(daoSpaceProxyASpaceId);
    vm.prank(address(daoSpaceProxyB));
    daoSpaceProxyB.addMember(daoSpaceProxyBSpaceId);

    assertEq(daoSpaceBeacon.implementation(), address(daoSpaceImplementationB));
    assertEq(daoSpaceImplementationB.version(), '2.0.0');
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
    assertEq(verifierSpaceBeacon.implementation(), address(verifierSpaceImplementationA));
    assertEq(verifierSpaceImplementationA.version(), '1.0.0');
    assertEq(verifierSpaceProxyA.version(), '1.0.0');
    assertEq(verifierSpaceProxyB.version(), '1.0.0');

    vm.prank(Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL);
    verifierSpaceBeacon.upgradeTo(address(verifierSpaceImplementationB));

    assertEq(verifierSpaceBeacon.implementation(), address(verifierSpaceImplementationB));
    assertEq(verifierSpaceImplementationB.version(), '2.0.0');
    assertEq(verifierSpaceProxyA.version(), '2.0.0');
    assertEq(verifierSpaceProxyB.version(), '2.0.0');
  }
}
