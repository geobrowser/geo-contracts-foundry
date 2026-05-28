// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

/**
 * @title IL2PaymentManager
 * @notice Minimal L2 PaymentManager surface used for cross-chain calldata encoding
 */
interface IL2PaymentManager {
  /**
   * @notice Sets the authorized payer for a Merkle target on Arbitrum
   * @param _targetId Canonical incentives target id for the space
   * @param _payer Address authorized to create payments for the target
   */
  function setPayer(bytes32 _targetId, address _payer) external;
}
