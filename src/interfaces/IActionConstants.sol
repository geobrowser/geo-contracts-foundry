// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

interface IActionConstants {
  /**
   * @notice The ID of the action to register a space
   * @return spaceIdRegistered The ID of the space registration action
   */
  function SPACE_ID_REGISTERED() external view returns (bytes32 spaceIdRegistered);

  /**
   * @notice The ID of the action to migrate a space
   * @return spaceIdMigrated The ID of the space migration action
   */
  function SPACE_ID_MIGRATED() external view returns (bytes32 spaceIdMigrated);
}
