// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {ERC1967Utils} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';
import {MockNewImplementation} from 'test/integration/mocks/MockNewImplementation.sol';

import {DAOSpaceFactory} from 'contracts/DAOSpaceFactory.sol';
import {SpaceRegistry} from 'contracts/SpaceRegistry.sol';
import {VerifierSpaceFactory} from 'contracts/VerifierSpaceFactory.sol';

import 'script/Constants.s.sol' as Constants;

contract IntegrationUpgradeUUPSImplementation is IntegrationBase {
  SpaceRegistry public spaceRegistryImplementationBis;
  DAOSpaceFactory public daoSpaceFactoryImplementationBis;
  VerifierSpaceFactory public verifierSpaceFactoryImplementationBis;

  function setUp() public override {
    IntegrationBase.setUp();
    vm.selectFork(_geoForkId);

    spaceRegistryImplementationBis = SpaceRegistry(address(new MockNewImplementation()));
    daoSpaceFactoryImplementationBis = DAOSpaceFactory(address(new MockNewImplementation()));
    verifierSpaceFactoryImplementationBis = VerifierSpaceFactory(address(new MockNewImplementation()));
  }

  function test_UpgradeUUPSImplementation_SpaceRegistry() external {
    assertEq(
      address(uint160(uint256(vm.load(address(spaceRegistryProxy), ERC1967Utils.IMPLEMENTATION_SLOT)))),
      address(spaceRegistryImplementation)
    );
    assertEq(spaceRegistryImplementation.version(), '1.0.0');
    assertEq(spaceRegistryProxy.version(), '1.0.0');

    vm.prank(Constants.GEO_GEO_MULTISIG_COUNCIL);
    spaceRegistryProxy.upgradeToAndCall(address(spaceRegistryImplementationBis), '');

    assertEq(
      address(uint160(uint256(vm.load(address(spaceRegistryProxy), ERC1967Utils.IMPLEMENTATION_SLOT)))),
      address(spaceRegistryImplementationBis)
    );
    assertEq(spaceRegistryImplementationBis.version(), '2.0.0');
    assertEq(spaceRegistryProxy.version(), '2.0.0');
  }

  function test_UpgradeUUPSImplementation_DAOSpaceFactory() external {
    assertEq(
      address(uint160(uint256(vm.load(address(daoSpaceFactoryProxy), ERC1967Utils.IMPLEMENTATION_SLOT)))),
      address(daoSpaceFactoryImplementation)
    );
    assertEq(daoSpaceFactoryImplementation.version(), '1.0.0');
    assertEq(daoSpaceFactoryProxy.version(), '1.0.0');

    vm.prank(Constants.GEO_GEO_MULTISIG_COUNCIL);
    daoSpaceFactoryProxy.upgradeToAndCall(address(daoSpaceFactoryImplementationBis), '');

    assertEq(
      address(uint160(uint256(vm.load(address(daoSpaceFactoryProxy), ERC1967Utils.IMPLEMENTATION_SLOT)))),
      address(daoSpaceFactoryImplementationBis)
    );
    assertEq(daoSpaceFactoryImplementationBis.version(), '2.0.0');
    assertEq(daoSpaceFactoryProxy.version(), '2.0.0');
  }

  function test_UpgradeUUPSImplementation_VerifierSpaceFactory() external {
    assertEq(
      address(uint160(uint256(vm.load(address(verifierSpaceFactoryProxy), ERC1967Utils.IMPLEMENTATION_SLOT)))),
      address(verifierSpaceFactoryImplementation)
    );
    assertEq(verifierSpaceFactoryImplementation.version(), '1.0.0');
    assertEq(verifierSpaceFactoryProxy.version(), '1.0.0');

    vm.prank(Constants.GEO_GEO_MULTISIG_COUNCIL);
    verifierSpaceFactoryProxy.upgradeToAndCall(address(verifierSpaceFactoryImplementationBis), '');

    assertEq(
      address(uint160(uint256(vm.load(address(verifierSpaceFactoryProxy), ERC1967Utils.IMPLEMENTATION_SLOT)))),
      address(verifierSpaceFactoryImplementationBis)
    );
    assertEq(verifierSpaceFactoryImplementationBis.version(), '2.0.0');
    assertEq(verifierSpaceFactoryProxy.version(), '2.0.0');
  }
}
