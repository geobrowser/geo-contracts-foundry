// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {DeployL1Contracts} from 'script/L1/DeployL1Contracts.s.sol';
import {TestHelper} from 'unit-helpers/TestHelper.sol';

import 'script/Constants.sol' as Constants;

/**
 * @title IntegrationL1Base
 * @notice Ethereum mainnet fork helpers; deploys `GEOToken` via `DeployL1Contracts`
 */
abstract contract IntegrationL1Base is TestHelper, DeployL1Contracts {
  uint256 internal constant _ETHEREUM_MAINNET_FORK_BLOCK = 25_195_000;

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('ethereum_mainnet'), _ETHEREUM_MAINNET_FORK_BLOCK);

    DeployL1Contracts.run();
  }

  function _mintGEO(address _to, uint256 _amount) internal {
    vm.prank(Constants.ETHEREUM_MAINNET_GEO_MULTISIG_COUNCIL);
    geoTokenProxy.mint(_to, _amount);
  }
}
