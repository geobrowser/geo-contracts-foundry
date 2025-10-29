// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

interface IEmitter {
  /**
   * @notice Emitted when a user calls the enter function
   * @param spaces The spaces involved
   *        bytes16: from space
   *        bytes16: to space
   * @param action An action, which is passed to the space contract
   * @param topic A topic, which is passed to the space contract
   * @param data Some arbitrary data for space contract execution
   */
  event Ping(bytes32 indexed spaces, bytes32 indexed action, bytes32 indexed topic, bytes data);
}
