// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {IPluginSetup} from '@aragon/osx/framework/plugin/setup/IPluginSetup.sol';

import {IMajorityVoting} from 'interfaces/governance/base/IMajorityVoting.sol';

/// @title IGovernancePluginsSetup
/// @dev Release 1, Build 1
interface IGovernancePluginsSetup is IPluginSetup {
  event GeoGovernancePluginsCreated(address dao, address mainVotingPlugin, address memberAccessPlugin);

  /// @notice Thrown when the array of helpers does not have the correct size
  error InvalidHelpers(uint256 actualLength);

  /// @notice Returns the address of the MemberAccessPlugin implementation
  function memberAccessPluginImplementation() external view returns (address);

  /// @notice Encodes the given installation parameters into a byte array
  function encodeInstallationParams(
    IMajorityVoting.VotingSettings calldata _votingSettings,
    address[] calldata _initialEditors,
    address[] calldata _initialMembers,
    uint64 _memberAccessProposalDuration
  ) external pure returns (bytes memory);

  /// @notice Decodes the given byte array into the original installation parameters
  function decodeInstallationParams(bytes memory _data)
    external
    pure
    returns (
      IMajorityVoting.VotingSettings memory votingSettings,
      address[] memory initialEditors,
      address[] memory initialMembers,
      uint64 memberAccessProposalDuration
    );
}
