// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IEmitter, MockEmitter} from 'contracts/test/MockEmitter.sol';
import {Script} from 'forge-std/Script.sol';

contract Deploy is Script {
  function run() public returns (IEmitter _emitter) {
    vm.startBroadcast();
    _emitter = new MockEmitter();
    vm.stopBroadcast();
  }
}
