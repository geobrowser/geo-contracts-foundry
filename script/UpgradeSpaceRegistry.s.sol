// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {Script} from 'forge-std/Script.sol';

import {Options} from '@openzeppelin/foundry-upgrades/Options.sol';
import {Upgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {SpaceRegistry} from 'contracts/SpaceRegistry.sol';

import 'script/Constants.s.sol' as Constants;

contract UpgradeSpaceRegistry is Script {
  SpaceRegistry public spaceRegistryImplementation;

  function run() public {
    vm.startBroadcast(Constants.GEO_GEO_MULTISIG_COUNCIL);

    // Deploy and upgrade to the new implementation contract
    bytes memory _upgraderData;
    Options memory _opts;
    _opts.referenceBuildInfoDir = 'previous-builds/space-registry';
    _opts.referenceContract = 'space-registry:src/contracts/SpaceRegistry.sol:SpaceRegistry';
    Upgrades.upgradeProxy(Constants.GEO_SPACE_REGISTRY_PROXY, 'SpaceRegistry.sol:SpaceRegistry', _upgraderData, _opts);
    spaceRegistryImplementation = SpaceRegistry(Upgrades.getImplementationAddress(Constants.GEO_SPACE_REGISTRY_PROXY));

    vm.stopBroadcast();
  }
}
