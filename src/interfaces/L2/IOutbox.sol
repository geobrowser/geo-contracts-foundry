// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

/**
 * @title IOutbox
 * @notice Minimal Arbitrum-style outbox surface used to recover the L2/L3 sender of a cross-domain message
 */
interface IOutbox {
  /**
   * @notice Returns the sender of the L2-to-L1 message currently being executed
   * @return _sender The account that initiated the message on the sending chain
   */
  function l2ToL1Sender() external view returns (address _sender);
}
