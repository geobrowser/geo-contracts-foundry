// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

/// @title IEditors
/// @notice An interface to be implemented by DAO plugins that define editorship.
interface IEditors {
  /// @notice Emitted when editors are added to the DAO plugin.
  /// @param dao The address of the DAO whose plugin has added editors.
  /// @param editors The addresses of the new editors.
  event EditorsAdded(address dao, address[] editors);

  /// @notice Emitted when an editor is added to the DAO plugin.
  /// @param dao The address of the DAO whose plugin has added an editor.
  /// @param editor The address of the new editor.
  event EditorAdded(address dao, address editor);

  /// @notice Emitted when an editor is removed from the DAO plugin.
  /// @param dao The address of the DAO whose plugin has removed an editor.
  /// @param editor The address of the editor being removed.
  event EditorRemoved(address dao, address editor);

  /// @notice Emitted when an editor left the space.
  /// @param dao The address of the DAO whose plugin has lost an editor.
  /// @param editor The address of the editor leaving.
  event EditorLeft(address dao, address editor);

  /// @notice Checks if an account is an editor.
  /// @param _account The address of the account to be checked.
  /// @return Whether the account is an editor or not.
  function isEditor(address _account) external view returns (bool);
}
