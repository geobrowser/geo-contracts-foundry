// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {Script} from 'forge-std/Script.sol';

import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {SpaceRegistry} from 'contracts/SpaceRegistry.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';

import 'script/Constants.s.sol' as Constants;

contract DeployGEOBrowser is Script {
  SpaceRegistry public spaceRegistryImplementation;
  SpaceRegistry public spaceRegistryProxy;

  function setUp() public virtual {}

  function run() public {
    vm.startBroadcast();

    // Deploy the implementation contracts
    spaceRegistryImplementation = new SpaceRegistry();

    // Deploy and initialize the proxy contracts
    spaceRegistryProxy = SpaceRegistry(
      UnsafeUpgrades.deployUUPSProxy(
        address(spaceRegistryImplementation),
        abi.encodeCall(ISpaceRegistry.initialize, (abi.encode(Constants.GEO_GENESIS_GEO_MULTISIG_COUNCIL)))
      )
    );

    vm.stopBroadcast();
  }
}
