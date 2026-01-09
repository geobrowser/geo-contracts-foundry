// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {Script} from 'forge-std/Script.sol';

import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {DAOSpaceFactory} from 'contracts/DAOSpaceFactory.sol';
import {SpaceRegistry} from 'contracts/SpaceRegistry.sol';
import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {VerifierSpaceFactory} from 'contracts/VerifierSpaceFactory.sol';

import 'script/Constants.s.sol' as Constants;

contract DeployGEOBrowser is Script {
  SpaceRegistry public spaceRegistryImplementation;
  SpaceRegistry public spaceRegistryProxy;

  DAOSpaceFactory public daoSpaceFactoryImplementation;
  DAOSpaceFactory public daoSpaceFactoryProxy;

  DAOSpace public daoSpaceImplementation;
  UpgradeableBeacon public daoSpaceBeacon;

  VerifierSpaceFactory public verifierSpaceFactoryImplementation;
  VerifierSpaceFactory public verifierSpaceFactoryProxy;

  VerifierSpace public verifierSpaceImplementation;
  UpgradeableBeacon public verifierSpaceBeacon;

  function setUp() public virtual {}

  function run() public {
    vm.startBroadcast();

    // Deploy the implementation contracts
    spaceRegistryImplementation = new SpaceRegistry();
    daoSpaceFactoryImplementation = new DAOSpaceFactory();
    daoSpaceImplementation = new DAOSpace();
    verifierSpaceFactoryImplementation = new VerifierSpaceFactory();
    verifierSpaceImplementation = new VerifierSpace();

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
          DAOSpaceFactory.initialize,
          (abi.encode(spaceRegistryProxy, Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL, address(daoSpaceImplementation)))
        )
      )
    );
    daoSpaceBeacon = UpgradeableBeacon(daoSpaceFactoryProxy.daoSpaceBeacon());
    verifierSpaceFactoryProxy = VerifierSpaceFactory(
      UnsafeUpgrades.deployUUPSProxy(
        address(verifierSpaceFactoryImplementation),
        abi.encodeCall(
          VerifierSpaceFactory.initialize,
          (abi.encode(
              spaceRegistryProxy, Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL, address(verifierSpaceImplementation)
            ))
        )
      )
    );
    verifierSpaceBeacon = UpgradeableBeacon(verifierSpaceFactoryProxy.verifierSpaceBeacon());

    vm.stopBroadcast();
  }
}
