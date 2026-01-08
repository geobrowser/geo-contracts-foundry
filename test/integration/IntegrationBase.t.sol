// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {DeployGEOBrowser} from 'script/DeployGEOBrowser.s.sol';

abstract contract IntegrationBase is TestHelper, DeployGEOBrowser {
  uint256 internal constant _ARBITRUM_TESTNET_FORK_BLOCK = 200_000_000;
  uint256 internal constant _GEO_TESTNET_FORK_BLOCK = 500;

  uint256 internal _arbitrumTestnetForkId;
  uint256 internal _geoTestnetForkId;

  IDAOSpace.VotingSettings internal _votingSettings;
  bytes16[] internal _initialSpaceEditors;
  bytes16[] internal _initialSpaceMembers;
  address internal _initialSpaceOwner;
  bytes internal _initialEditsContentUri;
  bytes internal _initialEditsMetadata;

  function setUp() public virtual override {
    _arbitrumTestnetForkId = vm.createFork(vm.rpcUrl('arbitrum_testnet'), _ARBITRUM_TESTNET_FORK_BLOCK);
    _geoTestnetForkId = vm.createFork(vm.rpcUrl('geo_testnet'), _GEO_TESTNET_FORK_BLOCK);

    // Deploy GEO incentives contracts on Arbitrum Testnet
    vm.selectFork(_arbitrumTestnetForkId);
    _deployGEOIncentives();

    // Deploy GEO browser contracts on Geo Testnet
    vm.selectFork(_geoTestnetForkId);
    _deployGEOBrowser();
  }

  function _deployGEOIncentives() internal {}

  function _deployGEOBrowser() internal {
    // Set up and run deployment script
    DeployGEOBrowser.setUp();
    DeployGEOBrowser.run();
  }
}
