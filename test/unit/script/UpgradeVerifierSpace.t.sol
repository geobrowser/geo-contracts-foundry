// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';

import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {UpgradeVerifierSpace} from 'script/UpgradeVerifierSpace.s.sol';

import 'script/Constants.s.sol' as Constants;

contract UnitUpgradeVerifierSpacerun is TestHelper {
  UpgradeVerifierSpace public upgradeVerifierSpace;

  function setUp() external {
    deployCodeTo('VerifierSpace.sol:VerifierSpace', Constants.GEO_VERIFIER_SPACE_IMPLEMENTATION);
    deployCodeTo(
      'UpgradeableBeacon.sol:UpgradeableBeacon',
      abi.encode(Constants.GEO_VERIFIER_SPACE_IMPLEMENTATION, Constants.GEO_GEO_MULTISIG_COUNCIL),
      Constants.GEO_VERIFIER_SPACE_BEACON
    );

    upgradeVerifierSpace = new UpgradeVerifierSpace();
  }

  function test_WhenCalled() external {
    assertEq(
      UpgradeableBeacon(Constants.GEO_VERIFIER_SPACE_BEACON).implementation(),
      Constants.GEO_VERIFIER_SPACE_IMPLEMENTATION
    );

    // when called
    upgradeVerifierSpace.run();

    // it deploys VerifierSpace implementation
    assertEq(address(upgradeVerifierSpace.verifierSpaceImplementation()).code, type(VerifierSpace).runtimeCode);

    // it upgrades VerifierSpace beacon
    assertEq(
      UpgradeableBeacon(Constants.GEO_VERIFIER_SPACE_BEACON).implementation(),
      address(upgradeVerifierSpace.verifierSpaceImplementation())
    );
    assertNotEq(
      address(upgradeVerifierSpace.verifierSpaceImplementation()), Constants.GEO_VERIFIER_SPACE_IMPLEMENTATION
    );
  }
}
