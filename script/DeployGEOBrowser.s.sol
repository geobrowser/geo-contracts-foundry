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
import 'src/ActionsConstants.sol' as ActionsConstants;

contract DeployGEOBrowser is Script {
  error DeploymentFailed(string _reason);

  SpaceRegistry public spaceRegistryImplementation;
  SpaceRegistry public spaceRegistryProxy;

  DAOSpaceFactory public daoSpaceFactoryImplementation;
  DAOSpaceFactory public daoSpaceFactoryProxy;

  DAOSpace public daoSpaceImplementation;

  VerifierSpaceFactory public verifierSpaceFactoryImplementation;
  VerifierSpaceFactory public verifierSpaceFactoryProxy;

  VerifierSpace public verifierSpaceImplementation;

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

    // Sanity check on deployments
    _verifyDeployments();

    vm.stopBroadcast();
  }

  function _verifyDeployments() internal view {
    _verifySpaceRegistry();
    _verifyDAOSpaceFactory();
    _verifyVerifierSpaceFactory();
  }

  function _verifySpaceRegistry() internal view {
    if (address(spaceRegistryProxy) == address(0)) {
      revert DeploymentFailed('SpaceRegistry: Proxy not deployed');
    }

    if (spaceRegistryProxy.owner() != Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL) {
      revert DeploymentFailed('SpaceRegistry: Owner not set correctly');
    }

    if (!spaceRegistryProxy.permissionlessActions(ActionsConstants.UPVOTED)) {
      revert DeploymentFailed('SpaceRegistry: UPVOTED permissionless action not added');
    }

    if (!spaceRegistryProxy.permissionlessActions(ActionsConstants.DOWNVOTED)) {
      revert DeploymentFailed('SpaceRegistry: DOWNVOTED permissionless action not added');
    }

    if (!spaceRegistryProxy.permissionlessActions(ActionsConstants.UNVOTED)) {
      revert DeploymentFailed('SpaceRegistry: UNVOTED permissionless action not added');
    }

    if (!spaceRegistryProxy.permissionlessActions(ActionsConstants.COMMENTED)) {
      revert DeploymentFailed('SpaceRegistry: COMMENTED permissionless action not added');
    }

    bytes16 spaceId = spaceRegistryProxy.addressToSpaceId(address(spaceRegistryProxy));
    if (spaceId == bytes16(0)) {
      revert DeploymentFailed('SpaceRegistry: SpaceRegistry not registered with itself');
    }

    if (spaceRegistryProxy.spaceIdToAddress(spaceId) != address(spaceRegistryProxy)) {
      revert DeploymentFailed('SpaceRegistry: SpaceId mapping incorrect');
    }
  }

  function _verifyDAOSpaceFactory() internal view {
    if (address(daoSpaceFactoryProxy) == address(0)) {
      revert DeploymentFailed('DAOSpaceFactory: Proxy not deployed');
    }

    if (daoSpaceFactoryProxy.owner() != Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL) {
      revert DeploymentFailed('DAOSpaceFactory: Owner not set correctly');
    }

    address daoSpaceBeacon = daoSpaceFactoryProxy.daoSpaceBeacon();
    if (daoSpaceBeacon == address(0)) {
      revert DeploymentFailed('DAOSpaceFactory: DAO space beacon not set');
    }

    UpgradeableBeacon beacon = UpgradeableBeacon(daoSpaceBeacon);
    if (beacon.implementation() != address(daoSpaceImplementation)) {
      revert DeploymentFailed('DAOSpaceFactory: DAO space beacon implementation incorrect');
    }

    if (beacon.owner() != Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL) {
      revert DeploymentFailed('DAOSpaceFactory: DAO space beacon owner incorrect');
    }

    if (address(daoSpaceFactoryProxy.spaceRegistry()) != address(spaceRegistryProxy)) {
      revert DeploymentFailed('DAOSpaceFactory: SpaceRegistry not set correctly');
    }
  }

  function _verifyVerifierSpaceFactory() internal view {
    if (address(verifierSpaceFactoryProxy) == address(0)) {
      revert DeploymentFailed('VerifierSpaceFactory: Proxy not deployed');
    }

    if (verifierSpaceFactoryProxy.owner() != Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL) {
      revert DeploymentFailed('VerifierSpaceFactory: Owner not set correctly');
    }

    address verifierSpaceBeacon = verifierSpaceFactoryProxy.verifierSpaceBeacon();
    if (verifierSpaceBeacon == address(0)) {
      revert DeploymentFailed('VerifierSpaceFactory: Verifier space beacon not set');
    }

    UpgradeableBeacon beacon = UpgradeableBeacon(verifierSpaceBeacon);
    if (beacon.implementation() != address(verifierSpaceImplementation)) {
      revert DeploymentFailed('VerifierSpaceFactory: Verifier space beacon implementation incorrect');
    }

    if (beacon.owner() != Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL) {
      revert DeploymentFailed('VerifierSpaceFactory: Verifier space beacon owner incorrect');
    }

    if (address(verifierSpaceFactoryProxy.spaceRegistry()) != address(spaceRegistryProxy)) {
      revert DeploymentFailed('VerifierSpaceFactory: SpaceRegistry not set correctly');
    }
  }
}
