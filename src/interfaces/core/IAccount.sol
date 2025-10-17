// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IAccount {
  error InvalidSignature();

  function verify(
    address _space,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external;
}
