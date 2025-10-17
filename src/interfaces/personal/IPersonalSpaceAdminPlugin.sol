// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {IDAO} from '@aragon/osx/core/dao/IDAO.sol';
import {IPlugin} from '@aragon/osx/core/plugin/IPlugin.sol';
import {IProposal} from '@aragon/osx/core/plugin/proposal/IProposal.sol';

import {IEditors} from 'interfaces/base/IEditors.sol';
import {IMembers} from 'interfaces/base/IMembers.sol';

/// @title IPersonalSpaceAdminPlugin
/// @author Aragon - 2023
/// @notice The admin governance plugin giving execution permission on the DAO to a single address.
interface IPersonalSpaceAdminPlugin is IPlugin, IProposal, IEditors, IMembers {
  /// @notice Raised when a wallet who is not an editor or a member attempts to do something
  error NotAMember(address caller);

  /// @notice Initializes the contract.
  /// @dev This method is required to support [ERC-1167](https://eips.ethereum.org/EIPS/eip-1167).
  /// @param _dao The associated DAO.
  /// @param _initialEditors The initial editors.
  /// @param _initialMembers The initial members.
  function initialize(IDAO _dao, address[] calldata _initialEditors, address[] calldata _initialMembers) external;

  /// @notice Returns whether the given address holds membership/editor permission on the plugin
  function isMember(address _account) external view returns (bool);

  /// @notice Returns whether the given address holds editor permission on the plugin
  function isEditor(address _account) external view returns (bool);

  /// @notice Creates and executes a new proposal.
  /// @param _metadata The metadata of the proposal.
  /// @param _actions The actions to be executed.
  /// @param _allowFailureMap A bitmap allowing the proposal to succeed, even if individual actions might revert. If the bit at index `i` is 1, the proposal succeeds even if the `i`th action reverts. A failure map value of 0 requires every action to not revert.
  function executeProposal(bytes calldata _metadata, IDAO.Action[] calldata _actions, uint256 _allowFailureMap) external;

  /// @notice Creates and executes a proposal that makes the DAO emit new content on the given space.
  /// @param _editsContentUri The URI of the IPFS content to publish.
  /// @param _editsMetadata The metadata of the edits to publish.
  /// @param _spacePlugin The address of the space plugin where changes will be executed.
  function submitEdits(string memory _editsContentUri, bytes memory _editsMetadata, address _spacePlugin) external;

  /// @notice Creates and executes a proposal that makes the DAO emit flag content on the given space.
  /// @param _flagContentUri The URI of the IPFS content to flag.
  /// @param _spacePlugin The address of the space plugin where changes will be executed.
  function submitFlagContent(string memory _flagContentUri, address _spacePlugin) external;

  /// @notice Creates and executes a proposal that makes the DAO accept the given DAO as a subspace.
  /// @param _subspaceDao The address of the DAO that holds the new subspace
  /// @param _spacePlugin The address of the space plugin where changes will be executed
  function submitAcceptSubspace(IDAO _subspaceDao, address _spacePlugin) external;

  /// @notice Creates and executes a proposal that makes the DAO remove the given DAO as a subspace.
  /// @param _subspaceDao The address of the DAO that holds the subspace to remove
  /// @param _spacePlugin The address of the space plugin where changes will be executed
  function submitRemoveSubspace(IDAO _subspaceDao, address _spacePlugin) external;

  /// @notice Creates and executes a proposal that makes the DAO grant membership permission to the given address
  /// @param _newMember The address to grant member permission to
  function submitNewMember(address _newMember) external;

  /// @notice Creates and executes a proposal that makes the DAO revoke membership permission from the given address
  /// @param _member The address that will no longer be a member
  function submitRemoveMember(address _member) external;

  /// @notice Creates and executes a proposal that makes the DAO revoke any permission from the sender address
  function leaveSpace() external;

  /// @notice Creates and executes a proposal that makes the DAO grant editor permission to the given address
  /// @param _newEditor The address to grant editor permission to
  function submitNewEditor(address _newEditor) external;

  /// @notice Creates and executes a proposal that makes the DAO revoke editor permission from the given address
  /// @param _editor The address that will no longer be an editor
  function submitRemoveEditor(address _editor) external;
}
