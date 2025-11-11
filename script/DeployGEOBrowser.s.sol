// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {Script} from 'forge-std/Script.sol';

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';

import {SpaceRegistry} from 'contracts/registry/SpaceRegistry.sol';
import {ISpaceRegistry} from 'interfaces/registry/ISpaceRegistry.sol';

import 'script/Constants.s.sol' as Constants;

contract DeployGEOBrowser is Script {
  SpaceRegistry public spaceRegistry;
  SpaceRegistry public spaceRegistryProxy;

  function setUp() public virtual {}

  function run() public {
    vm.startBroadcast();

    // Deploy the implementation contracts
    spaceRegistry = new SpaceRegistry();

    // Deploy and initialize the proxy contracts
    spaceRegistryProxy = SpaceRegistry(
      address(
        new ERC1967Proxy(
          address(spaceRegistry),
          abi.encodeCall(ISpaceRegistry.initialize, (Constants.GEO_GENESIS_GEO_MULTISIG_COUNCIL))
        )
      )
    );

    vm.stopBroadcast();
  }
}
