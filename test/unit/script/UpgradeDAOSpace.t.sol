// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {UpgradeDAOSpace} from 'script/UpgradeDAOSpace.s.sol';

import 'script/Constants.s.sol' as Constants;

contract UnitUpgradeDAOSpacerun is TestHelper {
  UpgradeDAOSpace public upgradeDAOSpace;

  function setUp() external {
    deployCodeTo('DAOSpace.sol:DAOSpace', Constants.GEO_DAO_SPACE_IMPLEMENTATION);
    deployCodeTo(
      'UpgradeableBeacon.sol:UpgradeableBeacon',
      abi.encode(Constants.GEO_DAO_SPACE_IMPLEMENTATION, Constants.GEO_GEO_MULTISIG_COUNCIL),
      Constants.GEO_DAO_SPACE_BEACON
    );

    upgradeDAOSpace = new UpgradeDAOSpace();
  }

  function test_WhenCalled() external {
    assertEq(UpgradeableBeacon(Constants.GEO_DAO_SPACE_BEACON).implementation(), Constants.GEO_DAO_SPACE_IMPLEMENTATION);

    // when called
    upgradeDAOSpace.run();

    // it deploys DAOSpace implementation
    assertEq(address(upgradeDAOSpace.daoSpaceImplementation()).code, type(DAOSpace).runtimeCode);

    // it upgrades DAOSpace beacon
    assertEq(
      UpgradeableBeacon(Constants.GEO_DAO_SPACE_BEACON).implementation(),
      address(upgradeDAOSpace.daoSpaceImplementation())
    );
    assertNotEq(address(upgradeDAOSpace.daoSpaceImplementation()), Constants.GEO_DAO_SPACE_IMPLEMENTATION);
  }
}
