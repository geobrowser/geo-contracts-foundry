// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {IDAO} from '@aragon/osx/core/dao/IDAO.sol';
import {PluginUUPSUpgradeable} from '@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol';
import {ArbSys} from '@arbitrum/nitro-contracts/src/precompiles/ArbSys.sol';

import {IPaymentManager} from 'interfaces/cross-chain/IPaymentManager.sol';
import {ISpacePlugin} from 'interfaces/space/ISpacePlugin.sol';
import {CONTENT_PERMISSION_ID, PAYER_PERMISSION_ID, SUBSPACE_PERMISSION_ID} from 'src/constants.sol';

/// @title SpacePlugin
/// @dev Release 1, Build 1
contract SpacePlugin is PluginUUPSUpgradeable, ISpacePlugin {
  /// @inheritdoc ISpacePlugin
  ArbSys public constant ARB_SYS = ArbSys(address(100));

  /// @inheritdoc ISpacePlugin
  address public paymentManager;

  /// @inheritdoc ISpacePlugin
  function initialize(
    IDAO _dao,
    address _paymentManager,
    string memory _firstEditsContentUri,
    bytes memory _firstEditsMetadata,
    address _predecessorSpace
  ) external initializer {
    if (_paymentManager == address(0)) revert InvalidAddress();

    __PluginUUPSUpgradeable_init(_dao);

    paymentManager = _paymentManager;

    if (_predecessorSpace != address(0)) {
      emit SuccessorSpaceCreated(address(dao()), _predecessorSpace);
    }
    emit EditsPublished({
      dao: address(dao()), editsContentUri: _firstEditsContentUri, editsMetadata: _firstEditsMetadata
    });
  }

  /// @inheritdoc PluginUUPSUpgradeable
  function supportsInterface(bytes4 _interfaceId) public view override returns (bool) {
    return _interfaceId == type(ISpacePlugin).interfaceId || super.supportsInterface(_interfaceId);
  }

  /// @inheritdoc ISpacePlugin
  function publishEdits(
    string memory _editsContentUri,
    bytes memory _editsMetadata
  ) external auth(CONTENT_PERMISSION_ID) {
    emit EditsPublished({dao: address(dao()), editsContentUri: _editsContentUri, editsMetadata: _editsMetadata});
  }

  /// @inheritdoc ISpacePlugin
  function flagContent(string memory _flagContentUri) external auth(CONTENT_PERMISSION_ID) {
    emit ContentFlagged({dao: address(dao()), flagContentUri: _flagContentUri});
  }

  /// @inheritdoc ISpacePlugin
  function acceptSubspace(address _subspaceDao) external auth(SUBSPACE_PERMISSION_ID) {
    emit SubspaceAccepted(address(dao()), _subspaceDao);
  }

  /// @inheritdoc ISpacePlugin
  function removeSubspace(address _subspaceDao) external auth(SUBSPACE_PERMISSION_ID) {
    emit SubspaceRemoved(address(dao()), _subspaceDao);
  }

  /// @inheritdoc ISpacePlugin
  function setPayer(address _payer) external auth(PAYER_PERMISSION_ID) {
    // Trigger cross-chain update
    bytes memory _data = abi.encodeCall(IPaymentManager.setPayer, (_payer));

    // Send message to L2 via ArbSys
    uint256 _txId = ARB_SYS.sendTxToL1(paymentManager, _data);

    emit PayerSet(address(dao()), _payer, _txId);
  }

  /// @notice This empty reserved space is put in place to allow future versions to add new variables without shifting down storage in the inheritance chain (see [OpenZeppelin's guide about storage gaps](https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps)).
  uint256[50] private __gap;
}
