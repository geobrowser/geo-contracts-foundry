// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {Script} from 'forge-std/Script.sol';

import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';
import {Options} from '@openzeppelin/foundry-upgrades/Options.sol';
import {Upgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {VerifierSpace} from 'contracts/VerifierSpace.sol';

import 'script/Constants.s.sol' as Constants;

contract UpgradeVerifierSpace is Script {
  VerifierSpace public verifierSpaceImplementation;

  function run() public {
    vm.startBroadcast(Constants.GEO_GEO_MULTISIG_COUNCIL);

    // Deploy and upgrade to the new implementation contract
    // REVIEW: @custom:oz-upgrades-from <reference>
    Options memory _opts;
    _opts.unsafeSkipAllChecks = true;
    Upgrades.upgradeBeacon(Constants.GEO_VERIFIER_SPACE_BEACON, 'VerifierSpace.sol:VerifierSpace', _opts);
    verifierSpaceImplementation = VerifierSpace(UpgradeableBeacon(Constants.GEO_VERIFIER_SPACE_BEACON).implementation());

    vm.stopBroadcast();
  }
}
