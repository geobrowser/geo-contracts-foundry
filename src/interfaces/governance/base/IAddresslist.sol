// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

/// @title IAddresslist
/// @notice A list of member addresses.
interface IAddresslist {
  /// @notice Thrown when the address list update is invalid, which can be caused by the addition of an existing member or removal of a non-existing member.
  /// @param member The array of member addresses to be added or removed.
  error InvalidAddresslistUpdate(address member);

  /// @notice Checks if an account is on the address list at a specific block number.
  /// @param _account The account address being checked.
  /// @param _blockNumber The block number.
  /// @return Whether the account is listed at the specified block number.
  function isListedAtBlock(address _account, uint256 _blockNumber) external view returns (bool);

  /// @notice Checks if an account is currently on the address list.
  /// @param _account The account address being checked.
  /// @return Whether the account is currently listed.
  function isListed(address _account) external view returns (bool);

  /// @notice Returns the length of the address list at a specific block number.
  /// @param _blockNumber The specific block to get the count from. If `0`, then the latest checkpoint value is returned.
  /// @return The address list length at the specified block number.
  function addresslistLengthAtBlock(uint256 _blockNumber) external view returns (uint256);

  /// @notice Returns the current length of the address list.
  /// @return The current address list length.
  function addresslistLength() external view returns (uint256);
}
