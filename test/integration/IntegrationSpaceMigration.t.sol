// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';

contract IntegrationSpaceMigration is IntegrationBase {
  address public eoaSpaceBis = makeAddr('eoaSpaceBis');
  DAOSpace public daoSpaceProxyBis;
  VerifierSpace public verifierSpaceProxyBis;

  function setUp() public override {
    IntegrationBase.setUp();
    vm.selectFork(_geoTestnetForkId);
  }

  function test_SpaceMigration_EOASpace() external {
    assertEq(spaceRegistryProxy.addressToSpaceId(eoaSpace), _eoaSpaceId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_eoaSpaceId), eoaSpace);

    vm.prank(eoaSpace);
    spaceRegistryProxy.proposeSpaceMigration(eoaSpaceBis);

    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_eoaSpaceId), eoaSpaceBis);

    vm.expectRevert(ISpaceRegistry.InvalidCaller.selector);
    vm.prank(eoaSpace);
    spaceRegistryProxy.acceptSpaceMigration(_eoaSpaceId, keccak256('EOA_SPACE'), '1.0.0');

    vm.prank(eoaSpaceBis);
    spaceRegistryProxy.acceptSpaceMigration(_eoaSpaceId, keccak256('EOA_SPACE'), '1.0.0');

    assertEq(spaceRegistryProxy.addressToSpaceId(eoaSpace), bytes16(0));
    assertEq(spaceRegistryProxy.addressToSpaceId(eoaSpaceBis), _eoaSpaceId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_eoaSpaceId), eoaSpaceBis);
    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_eoaSpaceId), address(0));
  }

  function test_SpaceMigration_DAOSpace() external {}

  function test_SpaceMigration_VerifierSpace() external {}
}
