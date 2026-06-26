// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Script} from 'forge-std/Script.sol';

import {Upgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {GEOToken} from 'contracts/L1/GEOToken.sol';
import {IGEOToken} from 'interfaces/L1/IGEOToken.sol';

import 'script/Constants.sol' as Constants;

contract DeployL1Contracts is Script {
  GEOToken public geoTokenImplementation;
  GEOToken public geoTokenProxy;

  IGEOToken.GEOTokenInitializationParams public geoTokenInitParams;

  function run() public virtual {
    // Set initialization parameters
    _setInitParams();

    vm.startBroadcast();

    geoTokenProxy = GEOToken(
      Upgrades.deployUUPSProxy('GEOToken.sol:GEOToken', abi.encodeCall(GEOToken.initialize, (geoTokenInitParams)))
    );
    geoTokenImplementation = GEOToken(Upgrades.getImplementationAddress(address(geoTokenProxy)));

    vm.stopBroadcast();
  }

  function _setInitParams() internal {
    // Set the initialization parameters
    geoTokenInitParams = IGEOToken.GEOTokenInitializationParams({
      council: Constants.ETHEREUM_MAINNET_GEO_MULTISIG_COUNCIL,
      minter: Constants.ETHEREUM_MAINNET_GEO_MULTISIG_COUNCIL,
      initialSupplyRecipient: Constants.ETHEREUM_MAINNET_INITIAL_SUPPLY_RECIPIENT,
      initialSupply: Constants.ETHEREUM_MAINNET_GEO_TOKEN_INITIAL_SUPPLY
    });
  }
}
