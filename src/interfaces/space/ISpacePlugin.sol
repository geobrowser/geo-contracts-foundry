// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IDAO} from '@aragon/osx/core/dao/IDAO.sol';
import {IPlugin} from '@aragon/osx/core/plugin/IPlugin.sol';
import {ArbSys} from '@arbitrum/nitro-contracts/src/precompiles/ArbSys.sol';

/// @title ISpacePlugin
/// @dev Release 1, Build 1
interface ISpacePlugin is IPlugin {
  /// @notice Emitted when the contents of a space change.
  /// @param dao The address of the DAO where this proposal was executed.
  /// @param editsContentUri An IPFS URI pointing to the new contents behind the block's item.
  /// @param editsMetadata The metadata associated with the new contents behind the block's item.
  event EditsPublished(address dao, string editsContentUri, bytes editsMetadata);

  /// @notice Emitted when a content is flagged.
  /// @param dao The address of the DAO where this proposal was executed.
  /// @param flagContentUri An IPFS URI pointing to the content being flagged.
  event ContentFlagged(address dao, string flagContentUri);

  /// @notice Announces that the current space plugin is the successor of an already existing Space
  /// @param dao The address of the DAO where this proposal was executed.
  /// @param predecessorSpace The address of the space contract that the plugin will replace
  event SuccessorSpaceCreated(address dao, address predecessorSpace);

  /// @notice Emitted when the DAO accepts another DAO as a subspace.
  /// @param dao The address of the DAO where this proposal was executed.
  /// @param subspaceDao The address of the DAO to be accepted as a subspace.
  event SubspaceAccepted(address dao, address subspaceDao);

  /// @notice Emitted when the DAO stops recognizing another DAO as a subspace.
  /// @param dao The address of the DAO where this proposal was executed.
  /// @param subspaceDao The address of the DAO to be removed as a subspace.
  event SubspaceRemoved(address dao, address subspaceDao);

  /// @notice Emitted when a payer is set for a Space DAO.
  /// @param dao The address of the DAO where this proposal was executed.
  /// @param payer The address authorized to create payments for that DAO (L2).
  /// @param _txId A unique identifier for the L3-to-L2 transaction.
  event PayerSet(address dao, address payer, uint256 _txId);

  /// @notice Raised when attempting to set an invalid address.
  error InvalidAddress();

  /// @notice Interacts with core Arbitrum-specific system-level functionality.
  /// @return arbSys Precompiled contract that exists in every Arbitrum chain at address(100), 0x0000000000000000000000000000000000000064.
  function ARB_SYS() external view returns (ArbSys arbSys);

  /// @notice The address of the PaymentManager contract (L2).
  /// @return paymentManager The address of the PaymentManager contract (L2).
  function paymentManager() external view returns (address paymentManager);

  /// @notice Initializes the plugin when build 1 is installed.
  /// @param _dao The address of the DAO to read the permissions from.
  /// @param _paymentManager The address of the PaymentManager contract (L2).
  /// @param _firstEditsContentUri An IPFS URI pointing to the contents of the first block's item (title).
  /// @param _firstEditsMetadata The metadata associated with the contents of the first block's item (title).
  /// @param _predecessorSpace Optionally, the address of the space contract preceding this one.
  function initialize(
    IDAO _dao,
    address _paymentManager,
    string memory _firstEditsContentUri,
    bytes memory _firstEditsMetadata,
    address _predecessorSpace
  ) external;

  /// @notice Emits an event with new contents for the given block index. Caller needs CONTENT_PERMISSION.
  /// @param _editsContentUri An IPFS URI pointing to the new contents behind the block's item.
  /// @param _editsMetadata The metadata associated with the new contents behind the block's item.
  function publishEdits(string memory _editsContentUri, bytes memory _editsMetadata) external;

  /// @notice Emits an event when the content is flagged. Caller needs CONTENT_PERMISSION.
  /// @param _flagContentUri An IPFS URI pointing to the content being flagged.
  function flagContent(string memory _flagContentUri) external;

  /// @notice Emits an event accepting another DAO as a subspace. Caller needs CONTENT_PERMISSION.
  /// @param _subspaceDao The address of the DAO to accept as a subspace.
  function acceptSubspace(address _subspaceDao) external;

  /// @notice Emits an event removing another DAO as a subspace. Caller needs CONTENT_PERMISSION.
  /// @param _subspaceDao The address of the DAO to remove as a subspace.
  function removeSubspace(address _subspaceDao) external;

  /// @notice Sets the payer address for the Space DAO.
  /// @param _payer The address authorized to create payments on behalf of the DAO (L2).
  function setPayer(address _payer) external;
}
