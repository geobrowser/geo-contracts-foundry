// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {PaymentManager} from 'contracts/L2/PaymentManager.sol';
import {IPaymentManager} from 'interfaces/L2/IPaymentManager.sol';

/**
 * @title MockPaymentManager
 * @notice Test helper exposing ERC-7201 storage location for `PaymentManager` unit tests
 */
contract MockPaymentManager is PaymentManager {
  /// @notice Exposes the ERC-7201 namespaced storage slot for `PaymentManager`
  function exposed__PAYMENT_MANAGER_STORAGE_LOCATION() external pure returns (bytes32 _paymentManagerStorageLocation) {
    _paymentManagerStorageLocation = _PAYMENT_MANAGER_STORAGE_LOCATION;
  }

  /// @notice Seeds target balance and payer without `processRewards` / `setPayer`
  function workaround_seedTargetBalanceAndPayer(bytes32 _targetId, uint256 _targetBalance, address _payer) external {
    PaymentManagerStorage storage $_ = _getPaymentManagerStorage();
    $_.totalTargetBalance[_targetId] = _targetBalance;
    $_.payers[_targetId] = _payer;
  }

  /// @notice Seeds a payment record and `paymentNonce` without `createPayment`
  function workaround_seedPaymentRecord(
    uint256 _paymentId,
    bytes32 _targetId,
    address _recipient,
    uint256 _amount,
    uint256 _unlockTime,
    uint256 _paymentNonce
  ) external {
    PaymentManagerStorage storage $_ = _getPaymentManagerStorage();
    $_.payments[_paymentId] = IPaymentManager.PaymentRequest({
      targetId: _targetId, recipient: _recipient, amount: _amount, unlockTime: _unlockTime
    });
    $_.paymentNonce = _paymentNonce;
  }
}
