// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {ERC1967Utils} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol';

import {SpaceRegistry} from 'contracts/SpaceRegistry.sol';
import {UpgradeSpaceRegistry} from 'script/UpgradeSpaceRegistry.s.sol';

import 'script/Constants.s.sol' as Constants;

contract UnitUpgradeSpaceRegistryrun is TestHelper {
  UpgradeSpaceRegistry public upgradeSpaceRegistry;

  function setUp() external {
    deployCodeTo('SpaceRegistry.sol:SpaceRegistry', Constants.GEO_SPACE_REGISTRY_IMPLEMENTATION);
    deployCodeTo(
      'ERC1967Proxy.sol:ERC1967Proxy',
      abi.encode(
        Constants.GEO_SPACE_REGISTRY_IMPLEMENTATION,
        abi.encodeCall(SpaceRegistry.initialize, (abi.encode(Constants.GEO_GEO_MULTISIG_COUNCIL)))
      ),
      Constants.GEO_SPACE_REGISTRY_PROXY
    );

    upgradeSpaceRegistry = new UpgradeSpaceRegistry();
  }

  function test_WhenCalled() external {
    assertEq(
      address(uint160(uint256(vm.load(Constants.GEO_SPACE_REGISTRY_PROXY, ERC1967Utils.IMPLEMENTATION_SLOT)))),
      Constants.GEO_SPACE_REGISTRY_IMPLEMENTATION
    );

    // when called
    upgradeSpaceRegistry.run();

    // it deploys SpaceRegistry implementation
    assertEq(upgradeSpaceRegistry.spaceRegistryImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    assertEq(upgradeSpaceRegistry.spaceRegistryImplementation().name(), 'SPACE_REGISTRY');

    // it upgrades SpaceRegistry proxy
    assertEq(
      address(uint160(uint256(vm.load(Constants.GEO_SPACE_REGISTRY_PROXY, ERC1967Utils.IMPLEMENTATION_SLOT)))),
      address(upgradeSpaceRegistry.spaceRegistryImplementation())
    );
    assertNotEq(
      address(upgradeSpaceRegistry.spaceRegistryImplementation()), Constants.GEO_SPACE_REGISTRY_IMPLEMENTATION
    );
  }
}
