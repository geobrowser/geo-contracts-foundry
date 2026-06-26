// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

/**
 * @title InvariantGEOToken
 * @notice Plain ERC-20 deployed for StakingManager invariant tests
 * @dev Staker balances are set with Foundry `deal`
 */
contract InvariantGEOToken is ERC20 {
  constructor() ERC20('Invariant GEO', 'invGEO') {}
}
