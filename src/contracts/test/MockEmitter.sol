// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IEmitter} from 'interfaces/core/IEmitter.sol';

/// @dev Mock Emitter with no verification for offchain testing
contract MockEmitter is IEmitter {
  /// @inheritdoc IEmitter
  function write(
    address _space,
    address _account,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external {
    emit Ping(_space, _account, _action, _topic, _data);
  }
}
