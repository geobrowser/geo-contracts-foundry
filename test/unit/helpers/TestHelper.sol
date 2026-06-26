// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Test} from 'forge-std/Test.sol';

abstract contract TestHelper is Test {
  // Helper function to mock and expect calls
  function _mockAndExpect(address target, bytes memory call, bytes memory returnData) internal {
    vm.mockCall(target, call, returnData);
    vm.expectCall(target, call);
  }

  // Helper function to avoid zero address, forge address and precompile address
  function _assumeFuzzable(address _address) internal pure {
    assumeNotForgeAddress(_address);
    assumeNotZeroAddress(_address);
    assumeNotPrecompile(_address);
  }
}
