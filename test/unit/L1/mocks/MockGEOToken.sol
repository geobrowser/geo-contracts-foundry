// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {GEOToken} from 'contracts/L1/GEOToken.sol';

/**
 * @title MockGEOToken
 * @notice Test helper exposing ERC-7201 storage location for unit tests.
 */
contract MockGEOToken is GEOToken {
  // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Nonces")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant _NONCES_STORAGE_LOCATION =
    0x5ab42ced628888259c08ac98db1eb0cf702fc1501344311d8b100cd1bfe4bb00;

  function exposed__GEO_TOKEN_STORAGE_LOCATION() external pure returns (bytes32 _geoTokenStorageLocation) {
    _geoTokenStorageLocation = _GEO_TOKEN_STORAGE_LOCATION;
  }

  /// @notice Mints balance to `_to` without calling external `mint` (isolates `burn` tests)
  function workaround_mintBalance(address _to, uint256 _amount) external {
    _mint(_to, _amount);
  }

  /// @notice Seeds permit nonce for `_account` without `permit`
  function workaround_seedNonce(address _account, uint256 _nonce) external {
    bytes32 _slot = keccak256(abi.encode(_account, _NONCES_STORAGE_LOCATION));
    assembly {
      sstore(_slot, _nonce)
    }
  }
}
