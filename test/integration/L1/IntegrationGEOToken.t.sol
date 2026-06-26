// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {IntegrationL1Base} from 'test/integration/L1/IntegrationL1Base.t.sol';

contract IntegrationGEOToken is IntegrationL1Base {
  address internal _holder = makeAddr('integration_geo_holder');

  function test_MintAndBurn() external {
    uint256 _mintAmount = 1_000_000e18;
    uint256 _burnAmount = 250_000e18;

    uint256 _balanceBefore = geoTokenProxy.balanceOf(_holder);

    _mintGEO(_holder, _mintAmount);
    assertEq(geoTokenProxy.balanceOf(_holder), _balanceBefore + _mintAmount);

    vm.prank(_holder);
    geoTokenProxy.burn(_burnAmount);
    assertEq(geoTokenProxy.balanceOf(_holder), _balanceBefore + _mintAmount - _burnAmount);
  }
}
