// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IPluginSetup} from '@aragon/osx/framework/plugin/setup/IPluginSetup.sol';

/// @title ISpacePluginSetup
/// @dev Release 1, Build 1
interface ISpacePluginSetup is IPluginSetup {
  /// @notice Emitted when a `SpacePlugin` plugin is created
  /// @param dao The address of the installing DAO
  /// @param plugin The address of the `SpacePlugin` plugin
  event GeoSpacePluginCreated(address dao, address plugin);

  /// @notice Encodes the given installation parameters into a byte array
  /// @param _paymentManager The address of the PaymentManager contract (L2)
  /// @param _firstBlockEditsContentUri An IPFS URI pointing to the contents of the first block's item (title)
  /// @param _firstBlockEditsMetadata The metadata associated with the contents of the first block's item (title)
  /// @param _predecessorAddress The address of the predecessor space contract
  /// @return data The encoded installation parameters
  function encodeInstallationParams(
    address _paymentManager,
    string memory _firstBlockEditsContentUri,
    bytes memory _firstBlockEditsMetadata,
    address _predecessorAddress
  ) external pure returns (bytes memory data);

  /// @notice Decodes the given byte array into the original installation parameters
  /// @param _data The encoded installation parameters
  /// @return paymentManager The address of the PaymentManager contract (L2)
  /// @return firstBlockEditsContentUri An IPFS URI pointing to the contents of the first block's item (title)
  /// @return firstBlockEditsMetadata The metadata associated with the contents of the first block's item (title)
  /// @return predecessorAddress The address of the predecessor space contract
  function decodeInstallationParams(bytes memory _data)
    external
    pure
    returns (
      address paymentManager,
      string memory firstBlockEditsContentUri,
      bytes memory firstBlockEditsMetadata,
      address predecessorAddress
    );
}
