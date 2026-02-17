// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {Script} from 'forge-std/Script.sol';

import {Options} from '@openzeppelin/foundry-upgrades/Options.sol';
import {Upgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {DAOSpaceFactory} from 'contracts/DAOSpaceFactory.sol';

import 'script/Constants.s.sol' as Constants;

contract UpgradeDAOSpaceFactory is Script {
  DAOSpaceFactory public daoSpaceFactoryImplementation;

  function run() public virtual {
    vm.startBroadcast(Constants.GEO_GEO_MULTISIG_COUNCIL);

    // Deploy and upgrade to the new implementation contract
    bytes memory _upgraderData;
    Options memory _opts;
    _opts.referenceBuildInfoDir = 'previous-builds/dao-space-factory';
    _opts.referenceContract = 'dao-space-factory:src/contracts/DAOSpaceFactory.sol:DAOSpaceFactory';
    Upgrades.upgradeProxy(
      Constants.GEO_DAO_SPACE_FACTORY_PROXY, 'DAOSpaceFactory.sol:DAOSpaceFactory', _upgraderData, _opts
    );
    daoSpaceFactoryImplementation =
      DAOSpaceFactory(Upgrades.getImplementationAddress(Constants.GEO_DAO_SPACE_FACTORY_PROXY));

    vm.stopBroadcast();
  }
}
