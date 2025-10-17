// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IEmitter {
  /**
   * @notice Emitted when a user calls the write function.
   * @param space The space contract.
   * @param account The account verification contract.
   * @param action An action, which is passed to the space contract.
   * @param topic A topic, which is passed to the space contract.
   * @param data Some arbitrary data for space contract execution.
   */
  event Ping(
    address indexed space, address indexed account, bytes32 indexed action, bytes32 indexed topic, bytes data
  ) anonymous;

  /**
   * @notice Broadcasts a message from the Emitter.
   * @param _space The space contract.
   * @param _account The account verification contract.
   * @param _action An action, which is passed to the space contract.
   * @param _topic A topic, which is passed to the space contract.
   * @param _data Some arbitrary data for space contract execution
   * @param _signature Account signatyre for verification.
   */
  function write(
    address _space,
    address _account,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external;
}
