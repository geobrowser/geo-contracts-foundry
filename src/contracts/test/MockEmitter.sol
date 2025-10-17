// SPDX-License-Identifier: AGPL-3.0-or-later
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
    bytes calldata _spaceData,
    bytes calldata _accountData
  ) external {
    emit Ping(_space, _account, _action, _topic, _spaceData);
  }
}
