// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {TestHelper} from 'unit-helpers/TestHelper.sol';

import {ERC1967Utils} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol';

import {IGEOToken} from 'interfaces/L1/IGEOToken.sol';
import {MockDeployL1Contracts} from 'test/unit/L1/mocks/MockDeployL1Contracts.sol';

import 'script/Constants.sol' as Constants;

contract UnitDeployL1Contractsrun is TestHelper {
  MockDeployL1Contracts public deployL1Contracts;

  function setUp() external {
    deployL1Contracts = new MockDeployL1Contracts();
  }

  function test_WhenCalled() external {
    deployL1Contracts.run();

    // it deploys GEOToken implementation
    assertEq(deployL1Contracts.geoTokenImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);

    IGEOToken.GEOTokenInitializationParams memory _geoTokenInitParams = deployL1Contracts.exposed_initParams();

    // it defines initialization parameters
    assertEq(_geoTokenInitParams.council, Constants.ETHEREUM_MAINNET_GEO_MULTISIG_COUNCIL);
    assertEq(_geoTokenInitParams.minter, Constants.ETHEREUM_MAINNET_GEO_MULTISIG_COUNCIL);
    assertEq(_geoTokenInitParams.initialSupplyRecipient, Constants.ETHEREUM_MAINNET_INITIAL_SUPPLY_RECIPIENT);
    assertEq(_geoTokenInitParams.initialSupply, Constants.ETHEREUM_MAINNET_GEO_TOKEN_INITIAL_SUPPLY);

    // it deploys and initializes GEOToken proxy
    assertEq(
      address(uint160(uint256(vm.load(address(deployL1Contracts.geoTokenProxy()), ERC1967Utils.IMPLEMENTATION_SLOT)))),
      address(deployL1Contracts.geoTokenImplementation())
    );
    assertEq(deployL1Contracts.geoTokenProxy().owner(), _geoTokenInitParams.council);
    assertEq(deployL1Contracts.geoTokenProxy().minter(), _geoTokenInitParams.minter);
    assertEq(
      deployL1Contracts.geoTokenProxy().balanceOf(_geoTokenInitParams.initialSupplyRecipient),
      _geoTokenInitParams.initialSupply
    );
  }
}
