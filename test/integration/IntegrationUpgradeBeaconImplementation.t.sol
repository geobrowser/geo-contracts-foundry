// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {MockNewImplementation} from 'test/integration/mocks/MockNewImplementation.sol';

import 'script/Constants.s.sol' as Constants;

contract IntegrationUpgradeBeaconImplementation is IntegrationBase {
  UpgradeableBeacon public daoSpaceBeacon;
  DAOSpace public daoSpaceImplementationA;
  DAOSpace public daoSpaceImplementationB;
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

    daoSpaceImplementationB = DAOSpace(address(new MockNewImplementation()));
    verifierSpaceImplementationB = VerifierSpace(address(new MockNewImplementation()));
  }

  function test_UpgradeBeaconImplementation_DAOSpace() external {
    assertEq(daoSpaceBeacon.implementation(), address(daoSpaceImplementationA));
    assertEq(daoSpaceImplementationA.version(), '1.0.0');
    assertEq(daoSpaceProxyA.version(), '1.0.0');
    assertEq(daoSpaceProxyB.version(), '1.0.0');

    vm.prank(Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL);
    daoSpaceBeacon.upgradeTo(address(daoSpaceImplementationB));

    assertEq(daoSpaceBeacon.implementation(), address(daoSpaceImplementationB));
    assertEq(daoSpaceImplementationB.version(), '2.0.0');
    assertEq(daoSpaceProxyA.version(), '2.0.0');
    assertEq(daoSpaceProxyB.version(), '2.0.0');
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
