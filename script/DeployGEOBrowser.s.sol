// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Script} from 'forge-std/Script.sol';

import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';
import {Upgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

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

  function run() public {
    vm.startBroadcast();

    // Deploy the implementation contracts for the beacons
    daoSpaceImplementation = new DAOSpace();
    verifierSpaceImplementation = new VerifierSpace();

    // Deploy and initialize the proxy contracts
    spaceRegistryProxy = SpaceRegistry(
      payable(Upgrades.deployUUPSProxy(
          'SpaceRegistry.sol:SpaceRegistry',
          abi.encodeCall(SpaceRegistry.initialize, (abi.encode(Constants.GEO_GEO_MULTISIG_COUNCIL)))
        ))
    );
    spaceRegistryImplementation = SpaceRegistry(Upgrades.getImplementationAddress(address(spaceRegistryProxy)));

    daoSpaceFactoryProxy = DAOSpaceFactory(
      payable(Upgrades.deployUUPSProxy(
          'DAOSpaceFactory.sol:DAOSpaceFactory',
          abi.encodeCall(
            DAOSpaceFactory.initialize,
            (abi.encode(spaceRegistryProxy, Constants.GEO_GEO_MULTISIG_COUNCIL, address(daoSpaceImplementation)))
          )
        ))
    );
    daoSpaceFactoryImplementation = DAOSpaceFactory(Upgrades.getImplementationAddress(address(daoSpaceFactoryProxy)));
    daoSpaceBeacon = UpgradeableBeacon(daoSpaceFactoryProxy.daoSpaceBeacon());

    verifierSpaceFactoryProxy = VerifierSpaceFactory(
      payable(Upgrades.deployUUPSProxy(
          'VerifierSpaceFactory.sol:VerifierSpaceFactory',
          abi.encodeCall(
            VerifierSpaceFactory.initialize,
            (abi.encode(spaceRegistryProxy, Constants.GEO_GEO_MULTISIG_COUNCIL, address(verifierSpaceImplementation)))
          )
        ))
    );
    verifierSpaceFactoryImplementation =
      VerifierSpaceFactory(Upgrades.getImplementationAddress(address(verifierSpaceFactoryProxy)));
    verifierSpaceBeacon = UpgradeableBeacon(verifierSpaceFactoryProxy.verifierSpaceBeacon());

    vm.stopBroadcast();
  }
}
