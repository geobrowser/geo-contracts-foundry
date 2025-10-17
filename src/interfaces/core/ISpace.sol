// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ISpace {
  function call(address _caller, bytes32 _action, bytes32 _topic, bytes calldata _data) external;
}
