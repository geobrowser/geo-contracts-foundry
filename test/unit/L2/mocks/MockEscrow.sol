// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Escrow} from 'contracts/L2/Escrow.sol';

/**
 * @title MockEscrow
 * @notice Test helper exposing ERC-7201 storage location for unit tests.
 */
contract MockEscrow is Escrow {
  /// @notice Exposes the ERC-7201 namespaced storage slot for `Escrow`
  function exposed__ESCROW_STORAGE_LOCATION() external pure returns (bytes32 _escrowStorageLocation) {
    _escrowStorageLocation = _ESCROW_STORAGE_LOCATION;
  }
}
