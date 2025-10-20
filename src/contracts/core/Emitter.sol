// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IAccount} from 'interfaces/core/IAccount.sol';
import {IEmitter} from 'interfaces/core/IEmitter.sol';
import {ISpace} from 'interfaces/core/ISpace.sol';

/// @dev PoC Basic Emitter
contract Emitter is IEmitter {
  /// @inheritdoc IEmitter
  function write(
    address _space,
    address _account,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external {
    // If msg.sender is not the space
    // Then pass the account, action, topic, and data to the space
    if (msg.sender != _space) ISpace(_space).write(_account, _action, _topic, _data);

    // If msg.sender is not the account
    // Then pass the space, action, topic, data, and signature for verification to the account
    if (msg.sender != _account) IAccount(_account).verify(_space, _action, _topic, _data, _signature);

    emit Ping(_space, _account, _action, _topic, _data);
  }
}
