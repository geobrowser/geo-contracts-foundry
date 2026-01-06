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
  MockDAOSpaceV2 public daoSpaceImplementationBis;
  MockDAOSpaceV2 public daoSpaceProxyA;
  MockDAOSpaceV2 public daoSpaceProxyB;

  UpgradeableBeacon public verifierSpaceBeacon;
  VerifierSpace public verifierSpaceImplementationBis;
  VerifierSpace public verifierSpaceProxyA;
  VerifierSpace public verifierSpaceProxyB;

  function setUp() public override {
    IntegrationBase.setUp();
    vm.selectFork(_geoTestnetForkId);

    daoSpaceBeacon = UpgradeableBeacon(daoSpaceFactoryProxy.daoSpaceBeacon());
    verifierSpaceBeacon = UpgradeableBeacon(verifierSpaceFactoryProxy.verifierSpaceBeacon());

    spaceRegistryProxy.registerSpaceId(keccak256('EOA_SPACE'), '1.0.0');
    _votingSettings.duration = daoSpaceImplementation.MINIMUM_VOTING_DURATION();
    _initialSpaceMembers = new address[](1);
    _initialSpaceMembers[0] = address(this);
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

    daoSpaceImplementationBis = new MockDAOSpaceV2();
    verifierSpaceImplementationBis = VerifierSpace(address(new MockNewImplementation()));
  }

  function test_UpgradeBeaconImplementation_DAOSpace() external {
    assertEq(daoSpaceBeacon.implementation(), address(daoSpaceImplementation));
    assertEq(daoSpaceImplementation.version(), '1.0.0');
    assertEq(daoSpaceProxyA.version(), '1.0.0');
    assertEq(daoSpaceProxyB.version(), '1.0.0');
    // _initialMembers
    assertTrue(daoSpaceProxyA.hasRole(daoSpaceProxyA.MEMBER(), address(this)));
    assertTrue(daoSpaceProxyB.hasRole(daoSpaceProxyB.MEMBER(), address(this)));
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
    daoSpaceBeacon.upgradeTo(address(daoSpaceImplementationBis));

    uint256 _initialTotalMembers = _initialSpaceMembers.length;
    daoSpaceProxyA.initialize(abi.encode(_initialTotalMembers));
    daoSpaceProxyB.initialize(abi.encode(_initialTotalMembers));

    vm.prank(address(daoSpaceProxyA));
    daoSpaceProxyA.addMember(address(daoSpaceProxyA));
    vm.prank(address(daoSpaceProxyB));
    daoSpaceProxyB.addMember(address(daoSpaceProxyB));

    assertEq(daoSpaceBeacon.implementation(), address(daoSpaceImplementationBis));
    assertEq(daoSpaceImplementationBis.version(), '2.0.0');
    assertEq(daoSpaceProxyA.version(), '2.0.0');
    assertEq(daoSpaceProxyB.version(), '2.0.0');
    // totalMembers
    assertEq(daoSpaceProxyA.totalMembers(), _initialTotalMembers + 1);
    assertEq(daoSpaceProxyB.totalMembers(), _initialTotalMembers + 1);
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
    assertEq(verifierSpaceBeacon.implementation(), address(verifierSpaceImplementation));
    assertEq(verifierSpaceImplementation.version(), '1.0.0');
    assertEq(verifierSpaceProxyA.version(), '1.0.0');
    assertEq(verifierSpaceProxyB.version(), '1.0.0');

    vm.prank(Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL);
    verifierSpaceBeacon.upgradeTo(address(verifierSpaceImplementationBis));

    assertEq(verifierSpaceBeacon.implementation(), address(verifierSpaceImplementationBis));
    assertEq(verifierSpaceImplementationBis.version(), '2.0.0');
    assertEq(verifierSpaceProxyA.version(), '2.0.0');
    assertEq(verifierSpaceProxyB.version(), '2.0.0');
  }
}
