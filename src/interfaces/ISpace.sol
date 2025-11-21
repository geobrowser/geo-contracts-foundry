// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

interface ISpace {
  /**
   * @notice Writes to this space from another space
   * @param _fromSpace The space contract that writes
   * @param _action The action to write
   * @param _topic The topic to write
   * @param _data The data to write
   */
  function write(address _fromSpace, bytes32 _action, bytes32 _topic, bytes calldata _data) external;

  /**
   * @notice Verifies a writing to another space from this space
   * @param _toSpace The space contract to verify
   * @param _action The action to verify
   * @param _topic The topic to verify
   * @param _data The data to verify
   * @param _signature The signature for verification
   */
  function verify(
    address _toSpace,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external;

  /**
   * @notice Fetches future output data for emission before execution
   * @param _action The action to use as the basis for future outputs
   * @param _topicInput The topic input to use as the basis for future outputs
   * @return _topicOutput The topic output to be emitted
   */
  function fetch(bytes32 _action, bytes32 _topicInput) external view returns (bytes32 _topicOutput);
}
