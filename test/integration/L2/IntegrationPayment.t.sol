// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {IPaymentManager} from 'interfaces/L2/IPaymentManager.sol';
import {IntegrationL2Base} from 'test/integration/L2/IntegrationL2Base.t.sol';

import 'script/Constants.sol' as Constants;

contract IntegrationPayment is IntegrationL2Base {
  function setUp() public override {
    IntegrationL2Base.setUp();

    // Prime payment manager balances via Rewarder.claimTargetRewards -> PaymentManager.processRewards.
    _publishTargetRewardsFixture();
    _fundWithArbitrumGeo(address(escrowProxy), _targetRewardsTotalClaimable());
    _claimTargetFixtureLeaf(_TARGET_REWARDS_PRIMARY_INDEX);
  }

  function test_SetPayer_WhenOutboxSenderIsSpaceRegistry() external {
    _mockOutboxSender(paymentManagerProxy.spaceRegistry());

    vm.expectEmit();
    emit IPaymentManager.PayerSet(_targetRewardsSpaceId0, _payer);
    paymentManagerProxy.setPayer(_targetRewardsSpaceId0, _payer);

    assertEq(paymentManagerProxy.payers(_targetRewardsSpaceId0), _payer);
  }

  function test_SetPayer_WhenOutboxSenderIsWrong() external {
    _mockOutboxSender(makeAddr('wrong_l3_sender'));

    vm.expectRevert(IPaymentManager.InvalidL3Sender.selector);
    paymentManagerProxy.setPayer(_targetRewardsSpaceId0, _payer);
  }

  function test_SetPayer_WhenPayerIsUnchanged() external {
    _mockOutboxSender(paymentManagerProxy.spaceRegistry());
    paymentManagerProxy.setPayer(_targetRewardsSpaceId0, _payer);
    _mockOutboxSender(paymentManagerProxy.spaceRegistry());
    paymentManagerProxy.setPayer(_targetRewardsSpaceId0, _payer);
    assertEq(paymentManagerProxy.payers(_targetRewardsSpaceId0), _payer);
  }

  function test_CreateExecuteAndSlashPayment() external {
    uint256 _payAmount = _TARGET_REWARDS_AMOUNT_0 / 2;

    assertEq(paymentManagerProxy.totalTargetBalance(_targetRewardsSpaceId0), _TARGET_REWARDS_AMOUNT_0);
    assertEq(_arbitrumGeoToken.balanceOf(address(paymentManagerProxy)), _TARGET_REWARDS_AMOUNT_0);

    _mockOutboxSender(paymentManagerProxy.spaceRegistry());
    paymentManagerProxy.setPayer(_targetRewardsSpaceId0, _payer);

    vm.prank(_payer);
    uint256 _paymentId = paymentManagerProxy.createPayment(_targetRewardsSpaceId0, _recipient, _payAmount);

    IPaymentManager.PaymentRequest memory _payment = paymentManagerProxy.payments(_paymentId);
    vm.warp(_payment.unlockTime);

    uint256 _recipientBefore = _arbitrumGeoToken.balanceOf(_recipient);
    paymentManagerProxy.executePayment(_paymentId);
    assertEq(_arbitrumGeoToken.balanceOf(_recipient), _recipientBefore + _payAmount);
    assertEq(paymentManagerProxy.totalTargetBalance(_targetRewardsSpaceId0), _payAmount);
    assertEq(_arbitrumGeoToken.balanceOf(address(paymentManagerProxy)), _payAmount);

    vm.prank(_payer);
    uint256 _slashPaymentId = paymentManagerProxy.createPayment(_targetRewardsSpaceId0, _recipient, _payAmount);

    uint256 _escrowBefore = _arbitrumGeoToken.balanceOf(address(escrowProxy));
    vm.prank(Constants.ARBITRUM_ONE_GEO_MULTISIG_COUNCIL);
    paymentManagerProxy.slashPayment(_slashPaymentId);
    assertEq(_arbitrumGeoToken.balanceOf(address(escrowProxy)), _escrowBefore + _payAmount);
    assertEq(_arbitrumGeoToken.balanceOf(address(paymentManagerProxy)), 0);
  }

  function test_ReclaimRewards(uint256 _reclaimAmount) external {
    assertEq(paymentManagerProxy.totalTargetBalance(_targetRewardsSpaceId0), _TARGET_REWARDS_AMOUNT_0);
    assertEq(_arbitrumGeoToken.balanceOf(address(paymentManagerProxy)), _TARGET_REWARDS_AMOUNT_0);

    _reclaimAmount = bound(_reclaimAmount, 1, _TARGET_REWARDS_AMOUNT_0);

    vm.expectEmit();
    emit IPaymentManager.RewardsReclaimed(_targetRewardsSpaceId0, _reclaimAmount);

    uint256 _escrowBefore = _arbitrumGeoToken.balanceOf(address(escrowProxy));
    uint256 _paymentManagerBefore = _arbitrumGeoToken.balanceOf(address(paymentManagerProxy));
    vm.prank(Constants.ARBITRUM_ONE_GEO_MULTISIG_COUNCIL);
    paymentManagerProxy.reclaimRewards(_targetRewardsSpaceId0, _reclaimAmount);

    assertEq(paymentManagerProxy.totalTargetBalance(_targetRewardsSpaceId0), _TARGET_REWARDS_AMOUNT_0 - _reclaimAmount);
    assertEq(_arbitrumGeoToken.balanceOf(address(escrowProxy)), _escrowBefore + _reclaimAmount);
    assertEq(_arbitrumGeoToken.balanceOf(address(paymentManagerProxy)), _paymentManagerBefore - _reclaimAmount);
  }
}
