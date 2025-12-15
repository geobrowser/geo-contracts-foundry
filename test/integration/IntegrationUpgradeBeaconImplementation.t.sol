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
  DAOSpace public daoSpaceProxyA;
  DAOSpace public daoSpaceProxyB;

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
    _initialSpaceOwner = address(this);

    daoSpaceProxyA =
      DAOSpace(daoSpaceFactoryProxy.createDAOSpaceProxy(_votingSettings, _initialSpaceEditors, _initialSpaceMembers));
    daoSpaceProxyB =
      DAOSpace(daoSpaceFactoryProxy.createDAOSpaceProxy(_votingSettings, _initialSpaceEditors, _initialSpaceMembers));
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
    // actionIsFastPathValid
    assertEq(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.addMember.selector), true);
    assertEq(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.addMember.selector), true);
    assertEq(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.removeMember.selector), true);
    assertEq(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.removeMember.selector), true);
    assertEq(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.addEditor.selector), false);
    assertEq(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.addEditor.selector), false);
    assertEq(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.removeEditor.selector), false);
    assertEq(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.removeEditor.selector), false);

    vm.prank(Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL);
    daoSpaceBeacon.upgradeTo(address(daoSpaceImplementationB));

    daoSpaceProxyA.initialize('');
    daoSpaceProxyB.initialize('');

    assertEq(daoSpaceBeacon.implementation(), address(daoSpaceImplementationB));
    assertEq(daoSpaceImplementationB.version(), '2.0.0');
    assertEq(daoSpaceProxyA.version(), '2.0.0');
    assertEq(daoSpaceProxyB.version(), '2.0.0');
    // actionIsFastPathValid
    assertEq(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.addMember.selector), false);
    assertEq(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.addMember.selector), false);
    assertEq(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.removeMember.selector), false);
    assertEq(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.removeMember.selector), false);
    assertEq(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.addEditor.selector), true);
    assertEq(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.addEditor.selector), true);
    assertEq(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.removeEditor.selector), true);
    assertEq(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.removeEditor.selector), true);
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
