// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

/**
 * @title IArbSys
 * @notice Minimal Arbitrum ArbSys precompile interface for L3 → L2 messaging
 */
interface IArbSys {
  /**
   * @notice Queues an L2 transaction to be executed via the parent chain outbox
   * @param _destination L2 contract address to call
   * @param _calldataForL2 Encoded call data for the L2 contract
   * @return _messageId Identifier for the queued message
   */
  function sendTxToL1(address _destination, bytes calldata _calldataForL2) external payable returns (uint256 _messageId);
}
