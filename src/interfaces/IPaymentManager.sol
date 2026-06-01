// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

/**
 * @title IPaymentManager
 * @notice Minimal PaymentManager interface used for cross-chain calldata encoding
 * @dev PaymentManager is deployed on Arbitrum L2; L3 callers encode `setPayer` for cross-chain delivery.
 */
interface IPaymentManager {
  /**
   * @notice Sets the payer for a Merkle target id via cross-chain message
   * @dev Caller must be the bridge path that surfaces `spaceRegistry` as `outbox.l2ToL1Sender()`
   * @param _targetId Merkle target identifier (must match the id used in Rewarder rewards)
   * @param _payer Address of the payer
   */
  function setPayer(bytes32 _targetId, address _payer) external;
}
