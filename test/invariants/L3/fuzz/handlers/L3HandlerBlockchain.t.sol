// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Test} from 'forge-std/Test.sol';

/// @notice Handler for blockchain-level operations (time, blocks, etc.)
/// @dev Extracted to avoid duplicate calls when multiple handlers inherit from BaseHandler
contract L3HandlerBlockchain is Test {
  uint256 internal constant _MAX_WARP_DELTA = 365 days;
  uint256 internal constant _MAX_ROLL_DELTA = 1_000_000;

  function handler_warp(uint256 _delta) external {
    vm.warp(vm.getBlockTimestamp() + bound(_delta, 0, _MAX_WARP_DELTA));
  }

  function handler_roll(uint256 _delta) external {
    vm.roll(block.number + bound(_delta, 0, _MAX_ROLL_DELTA));
  }
}
