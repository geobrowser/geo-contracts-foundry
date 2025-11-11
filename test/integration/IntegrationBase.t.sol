// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {DeployGEOBrowser} from 'script/DeployGEOBrowser.s.sol';

abstract contract IntegrationBase is TestHelper, DeployGEOBrowser {
  uint256 internal constant _ARBITRUM_ONE_FORK_BLOCK = 350_000_000;
  uint256 internal constant _GEO_GENESIS_FORK_BLOCK = 500;

  uint256 internal _arbitrumOneForkId;
  uint256 internal _geoGenesisForkId;

  function setUp() public virtual override {
    _arbitrumOneForkId = vm.createFork(vm.rpcUrl('arbitrum_one'), _ARBITRUM_ONE_FORK_BLOCK);
    _geoGenesisForkId = vm.createFork(vm.rpcUrl('geo_genesis'), _GEO_GENESIS_FORK_BLOCK);

    // Deploy GEO incentives contracts on Arbitrum One
    vm.selectFork(_arbitrumOneForkId);
    _deployGEOIncentives();

    // Deploy GEO browser contracts on Geo Genesis
    vm.selectFork(_geoGenesisForkId);
    _deployGEOBrowser();
  }

  function _deployGEOIncentives() internal {}

  function _deployGEOBrowser() internal {
    // Set up and run deployment script
    DeployGEOBrowser.setUp();
    DeployGEOBrowser.run();
  }
}
