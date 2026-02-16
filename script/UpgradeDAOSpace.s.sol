// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {Script} from 'forge-std/Script.sol';

import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';
import {Options} from '@openzeppelin/foundry-upgrades/Options.sol';
import {Upgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {DAOSpace} from 'contracts/DAOSpace.sol';

import 'script/Constants.s.sol' as Constants;

contract UpgradeDAOSpace is Script {
  DAOSpace public daoSpaceImplementation;

  function run() public {
    vm.startBroadcast(Constants.GEO_GEO_MULTISIG_COUNCIL);

    // Deploy and upgrade to the new implementation contract
    Options memory _opts;
    _opts.referenceBuildInfoDir = 'previous-builds/dao-space';
    _opts.referenceContract = 'dao-space:src/contracts/DAOSpace.sol:DAOSpace';

    Upgrades.upgradeBeacon(Constants.GEO_DAO_SPACE_BEACON, 'DAOSpace.sol:DAOSpace', _opts);
    daoSpaceImplementation = DAOSpace(UpgradeableBeacon(Constants.GEO_DAO_SPACE_BEACON).implementation());

    vm.stopBroadcast();
  }
}
