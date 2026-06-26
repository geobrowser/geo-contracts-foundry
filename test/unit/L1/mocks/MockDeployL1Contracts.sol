// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {IGEOToken} from 'interfaces/L1/IGEOToken.sol';
import {DeployL1Contracts} from 'script/L1/DeployL1Contracts.s.sol';

/**
 * @title MockDeployL1Contracts
 * @notice Mock contract for testing DeployL1Contracts with additional test helper functions
 */
contract MockDeployL1Contracts is DeployL1Contracts {
  function exposed_initParams()
    external
    view
    returns (IGEOToken.GEOTokenInitializationParams memory _geoTokenInitParams)
  {
    _geoTokenInitParams = geoTokenInitParams;
  }
}
