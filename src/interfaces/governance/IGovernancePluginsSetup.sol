// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IPluginSetup} from '@aragon/osx/framework/plugin/setup/IPluginSetup.sol';

import {IMajorityVoting} from 'interfaces/governance/base/IMajorityVoting.sol';

/// @title IGovernancePluginsSetup
/// @dev Release 1, Build 1
interface IGovernancePluginsSetup is IPluginSetup {
  /// @notice Emitted when the two governance plugins are created
  /// @param dao The address of the installing DAO
  /// @param mainVotingPlugin The address of the `MainVotingPlugin` plugin
  /// @param memberAccessPlugin The address of the `MemberAccessPlugin` plugin
  event GeoGovernancePluginsCreated(address dao, address mainVotingPlugin, address memberAccessPlugin);

  /// @notice Thrown when the array of helpers does not have the correct size
  /// @param actualLength The size of the array of helpers
  error InvalidHelpers(uint256 actualLength);

  /// @notice Returns the address of the `MemberAccessPlugin` implementation
  /// @return memberAccessPluginImplementation The address of the `MemberAccessPlugin` implementation
  function memberAccessPluginImplementation() external view returns (address memberAccessPluginImplementation);

  /// @notice Encodes the given installation parameters into a byte array
  /// @param _votingSettings The voting settings on the `MainVotingPlugin` plugin
  /// @param _initialEditors The initial editors
  /// @param _initialMembers The initial members
  /// @param _memberAccessProposalDuration The duration of a proposal on the `MemberAccessPlugin` plugin
  /// @return data The encoded installation parameters
  function encodeInstallationParams(
    IMajorityVoting.VotingSettings calldata _votingSettings,
    address[] calldata _initialEditors,
    address[] calldata _initialMembers,
    uint64 _memberAccessProposalDuration
  ) external pure returns (bytes memory data);

  /// @notice Decodes the given byte array into the original installation parameters
  /// @param _data The encoded installation parameters
  /// @return votingSettings The voting settings on the `MainVotingPlugin` plugin
  /// @return initialEditors The initial editors
  /// @return initialMembers The initial members
  /// @return memberAccessProposalDuration The duration of a proposal on the `MemberAccessPlugin` plugin
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
