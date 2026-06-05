// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {UpgradeDAOSpace} from 'script/UpgradeDAOSpace.s.sol';
import {UpgradeDAOSpaceFactory} from 'script/UpgradeDAOSpaceFactory.s.sol';
import {UpgradeSpaceRegistry} from 'script/UpgradeSpaceRegistry.s.sol';
import {UpgradeVerifierSpace} from 'script/UpgradeVerifierSpace.s.sol';
import {UpgradeVerifierSpaceFactory} from 'script/UpgradeVerifierSpaceFactory.s.sol';

contract MasterUpgrade is
  UpgradeDAOSpace,
  UpgradeDAOSpaceFactory,
  UpgradeSpaceRegistry,
  UpgradeVerifierSpace,
  UpgradeVerifierSpaceFactory
{
  function run()
    public
    override(
      UpgradeDAOSpace,
      UpgradeDAOSpaceFactory,
      UpgradeSpaceRegistry,
      UpgradeVerifierSpace,
      UpgradeVerifierSpaceFactory
    )
  {
    UpgradeSpaceRegistry.run();
    UpgradeDAOSpaceFactory.run();
    UpgradeVerifierSpaceFactory.run();
    UpgradeDAOSpace.run();
    UpgradeVerifierSpace.run();
  }
}
