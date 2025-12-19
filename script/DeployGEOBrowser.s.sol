// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {Script} from 'forge-std/Script.sol';

import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {DAOSpaceFactory} from 'contracts/DAOSpaceFactory.sol';
import {SpaceRegistry} from 'contracts/SpaceRegistry.sol';
import {VerifierSpaceFactory} from 'contracts/VerifierSpaceFactory.sol';

import 'script/Constants.s.sol' as Constants;

contract DeployGEOBrowser is Script {
  SpaceRegistry public spaceRegistryImplementation;
  SpaceRegistry public spaceRegistryProxy;

  DAOSpaceFactory public daoSpaceFactoryImplementation;
  DAOSpaceFactory public daoSpaceFactoryProxy;

  VerifierSpaceFactory public verifierSpaceFactoryImplementation;
  VerifierSpaceFactory public verifierSpaceFactoryProxy;

  function setUp() public virtual {}

  function run() public {
    vm.startBroadcast();

    // Deploy the implementation contracts
    spaceRegistryImplementation = new SpaceRegistry();
    daoSpaceFactoryImplementation = new DAOSpaceFactory();
    verifierSpaceFactoryImplementation = new VerifierSpaceFactory();

    // Deploy and initialize the proxy contracts
    spaceRegistryProxy = SpaceRegistry(
      UnsafeUpgrades.deployUUPSProxy(
        address(spaceRegistryImplementation),
        abi.encodeCall(SpaceRegistry.initialize, (abi.encode(Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL)))
      )
    );
    daoSpaceFactoryProxy = DAOSpaceFactory(
      UnsafeUpgrades.deployUUPSProxy(
        address(daoSpaceFactoryImplementation),
        abi.encodeCall(
          DAOSpaceFactory.initialize, (abi.encode(spaceRegistryProxy, Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL))
        )
      )
    );
    verifierSpaceFactoryProxy = VerifierSpaceFactory(
      UnsafeUpgrades.deployUUPSProxy(
        address(verifierSpaceFactoryImplementation),
        abi.encodeCall(
          VerifierSpaceFactory.initialize, (abi.encode(spaceRegistryProxy, Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL))
        )
      )
    );

    vm.stopBroadcast();
  }
}
