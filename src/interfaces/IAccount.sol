// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

interface IAccount {
  /**
   * @notice Verifies a writing to a space
   * @param _space The space contract to verify
   * @param _action The action to verify
   * @param _topic The topic to verify
   * @param _data The data to verify
   * @param _signature The signature for verification
   */
  function verify(
    address _space,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external;
}
