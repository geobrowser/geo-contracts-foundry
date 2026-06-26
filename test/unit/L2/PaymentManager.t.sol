// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';
import {PaymentManager} from 'contracts/L2/PaymentManager.sol';
import {IOutbox} from 'interfaces/L2/IOutbox.sol';
import {IPaymentManager} from 'interfaces/L2/IPaymentManager.sol';
import {MockPaymentManager} from 'test/unit/L2/mocks/MockPaymentManager.sol';
import {TestHelper} from 'unit-helpers/TestHelper.sol';

contract UnitPaymentManager is TestHelper {
  address public council = makeAddr('council');

  address public arbitrumGeoToken = makeAddr('arbitrumGeoToken');
  address public outboxAddr = makeAddr('outbox');
  address public rewarderAddr = makeAddr('rewarderAddr');
  address public escrowAddr = makeAddr('escrow');
  address public spaceRegistry = makeAddr('spaceRegistry');
  address public spaceA = makeAddr('spaceA');
  address public payer = makeAddr('payer');
  address public recipient = makeAddr('recipient');
  address public alice = makeAddr('alice');

  uint256 public paymentDelay = 1 days;

  MockPaymentManager public paymentManagerImplementation;
  MockPaymentManager public paymentManagerProxy;

  function setUp() external {
    paymentManagerImplementation = new MockPaymentManager();
    paymentManagerProxy = MockPaymentManager(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(paymentManagerImplementation),
          abi.encodeCall(
            PaymentManager.initialize,
            (IPaymentManager.PaymentManagerInitializationParams({
                arbitrumGeoToken: arbitrumGeoToken,
                outbox: outboxAddr,
                rewarder: rewarderAddr,
                escrow: escrowAddr,
                spaceRegistry: spaceRegistry,
                council: council,
                paymentRequestDelay: paymentDelay
              }))
          )
        ))
    );
  }

  // -------- constants --------
  function test_Constants_WhenDeployed() external view {
    // when deployed
    // it sets _PAYMENT_MANAGER_STORAGE_LOCATION to keccak256(abi.encode(uint256(keccak256("geo.storage.PaymentManager")) - 1)) & ~bytes32(uint256(0xff))
    assertEq(
      paymentManagerImplementation.exposed__PAYMENT_MANAGER_STORAGE_LOCATION(),
      keccak256(abi.encode(uint256(keccak256('geo.storage.PaymentManager')) - 1)) & ~bytes32(uint256(0xff))
    );
  }

  // -------- constructor --------
  function test_Constructor_WhenCalled() external {
    // it disables initializers
    PaymentManager newImplementation = new PaymentManager();
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    newImplementation.initialize(
      IPaymentManager.PaymentManagerInitializationParams({
        arbitrumGeoToken: arbitrumGeoToken,
        outbox: outboxAddr,
        rewarder: rewarderAddr,
        escrow: escrowAddr,
        spaceRegistry: spaceRegistry,
        council: council,
        paymentRequestDelay: paymentDelay
      })
    );
  }

  // -------- initialize --------
  function test_Initialize_WhenPassingValidParameters(uint256 _paymentRequestDelay) external {
    // when passing valid parameters
    _paymentRequestDelay = bound(_paymentRequestDelay, 0, 365 days);
    paymentManagerImplementation = new MockPaymentManager();
    // it emits PaymentRequestDelaySet
    vm.expectEmit();
    emit IPaymentManager.PaymentRequestDelaySet(_paymentRequestDelay);
    MockPaymentManager freshPaymentManager = MockPaymentManager(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(paymentManagerImplementation),
          abi.encodeCall(
            PaymentManager.initialize,
            (IPaymentManager.PaymentManagerInitializationParams({
                arbitrumGeoToken: arbitrumGeoToken,
                outbox: outboxAddr,
                rewarder: rewarderAddr,
                escrow: escrowAddr,
                spaceRegistry: spaceRegistry,
                council: council,
                paymentRequestDelay: _paymentRequestDelay
              }))
          )
        ))
    );

    // it sets the owner
    assertEq(freshPaymentManager.owner(), council);
    // it sets arbitrumGeoToken
    assertEq(address(freshPaymentManager.arbitrumGeoToken()), arbitrumGeoToken);
    // it sets outbox
    assertEq(address(freshPaymentManager.outbox()), outboxAddr);
    // it sets rewarder
    assertEq(freshPaymentManager.rewarder(), rewarderAddr);
    // it sets escrow
    assertEq(freshPaymentManager.escrow(), escrowAddr);
    // it sets the spaceRegistry
    assertEq(freshPaymentManager.spaceRegistry(), spaceRegistry);
    // it sets the payment request delay
    assertEq(freshPaymentManager.paymentRequestDelay(), _paymentRequestDelay);
  }

  function test_Initialize_WhenCalledTwice() external {
    // when called twice
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    paymentManagerProxy.initialize(
      IPaymentManager.PaymentManagerInitializationParams({
        arbitrumGeoToken: arbitrumGeoToken,
        outbox: outboxAddr,
        rewarder: rewarderAddr,
        escrow: escrowAddr,
        spaceRegistry: spaceRegistry,
        council: council,
        paymentRequestDelay: paymentDelay
      })
    );
  }

  function test_Initialize_WhenArbitrumGeoTokenIsZero() external {
    // when arbitrumGeoToken is zero
    paymentManagerImplementation = new MockPaymentManager();
    vm.expectRevert(IPaymentManager.InvalidAddress.selector);
    UnsafeUpgrades.deployUUPSProxy(
      address(paymentManagerImplementation),
      abi.encodeCall(
        PaymentManager.initialize,
        (IPaymentManager.PaymentManagerInitializationParams({
            arbitrumGeoToken: address(0),
            outbox: outboxAddr,
            rewarder: rewarderAddr,
            escrow: escrowAddr,
            spaceRegistry: spaceRegistry,
            council: council,
            paymentRequestDelay: paymentDelay
          }))
      )
    );
  }

  function test_Initialize_WhenOutboxIsZero() external {
    // when outbox is zero
    paymentManagerImplementation = new MockPaymentManager();
    vm.expectRevert(IPaymentManager.InvalidAddress.selector);
    UnsafeUpgrades.deployUUPSProxy(
      address(paymentManagerImplementation),
      abi.encodeCall(
        PaymentManager.initialize,
        (IPaymentManager.PaymentManagerInitializationParams({
            arbitrumGeoToken: arbitrumGeoToken,
            outbox: address(0),
            rewarder: rewarderAddr,
            escrow: escrowAddr,
            spaceRegistry: spaceRegistry,
            council: council,
            paymentRequestDelay: paymentDelay
          }))
      )
    );
  }

  function test_Initialize_WhenRewarderIsZero() external {
    // when rewarder is zero
    paymentManagerImplementation = new MockPaymentManager();
    vm.expectRevert(IPaymentManager.InvalidAddress.selector);
    UnsafeUpgrades.deployUUPSProxy(
      address(paymentManagerImplementation),
      abi.encodeCall(
        PaymentManager.initialize,
        (IPaymentManager.PaymentManagerInitializationParams({
            arbitrumGeoToken: arbitrumGeoToken,
            outbox: outboxAddr,
            rewarder: address(0),
            escrow: escrowAddr,
            spaceRegistry: spaceRegistry,
            council: council,
            paymentRequestDelay: paymentDelay
          }))
      )
    );
  }

  function test_Initialize_WhenEscrowIsZero() external {
    // when escrow is zero
    paymentManagerImplementation = new MockPaymentManager();
    vm.expectRevert(IPaymentManager.InvalidAddress.selector);
    UnsafeUpgrades.deployUUPSProxy(
      address(paymentManagerImplementation),
      abi.encodeCall(
        PaymentManager.initialize,
        (IPaymentManager.PaymentManagerInitializationParams({
            arbitrumGeoToken: arbitrumGeoToken,
            outbox: outboxAddr,
            rewarder: rewarderAddr,
            escrow: address(0),
            spaceRegistry: spaceRegistry,
            council: council,
            paymentRequestDelay: paymentDelay
          }))
      )
    );
  }

  function test_Initialize_WhenSpaceRegistryIsZero() external {
    // when spaceRegistry is zero
    paymentManagerImplementation = new MockPaymentManager();
    vm.expectRevert(IPaymentManager.InvalidAddress.selector);
    UnsafeUpgrades.deployUUPSProxy(
      address(paymentManagerImplementation),
      abi.encodeCall(
        PaymentManager.initialize,
        (IPaymentManager.PaymentManagerInitializationParams({
            arbitrumGeoToken: arbitrumGeoToken,
            outbox: outboxAddr,
            rewarder: rewarderAddr,
            escrow: escrowAddr,
            spaceRegistry: address(0),
            council: council,
            paymentRequestDelay: paymentDelay
          }))
      )
    );
  }

  function test_Initialize_WhenCouncilIsZero() external {
    // when council is zero
    paymentManagerImplementation = new MockPaymentManager();
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
    UnsafeUpgrades.deployUUPSProxy(
      address(paymentManagerImplementation),
      abi.encodeCall(
        PaymentManager.initialize,
        (IPaymentManager.PaymentManagerInitializationParams({
            arbitrumGeoToken: arbitrumGeoToken,
            outbox: outboxAddr,
            rewarder: rewarderAddr,
            escrow: escrowAddr,
            spaceRegistry: spaceRegistry,
            council: address(0),
            paymentRequestDelay: paymentDelay
          }))
      )
    );
  }

  // -------- setPaymentRequestDelay --------
  function test_SetPaymentRequestDelay_WhenCalledByOwner(uint256 _newDelay) external {
    // when called by owner
    _newDelay = bound(_newDelay, 1, 30 days);
    // it emits PaymentRequestDelaySet
    vm.expectEmit();
    emit IPaymentManager.PaymentRequestDelaySet(_newDelay);
    vm.prank(council);
    paymentManagerProxy.setPaymentRequestDelay(_newDelay);
    // it sets the new delay
    assertEq(paymentManagerProxy.paymentRequestDelay(), _newDelay);
  }

  function test_SetPaymentRequestDelay_WhenCalledByNon_owner(address _caller, uint256 _delay) external {
    // when called by non-owner
    _assumeFuzzable(_caller);
    vm.assume(_caller != council);
    _delay = bound(_delay, 1, 30 days);
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    paymentManagerProxy.setPaymentRequestDelay(_delay);
  }

  // -------- setPayer --------
  function test_SetPayer_WhenTargetIdIsZero() external {
    // when target id is zero
    vm.expectRevert(IPaymentManager.InvalidTargetId.selector);
    paymentManagerProxy.setPayer(bytes32(0), payer);
  }

  function test_SetPayer_WhenL3SenderIsNotSpaceRegistry(address _wrongSender) external {
    // when l3 sender is not spaceRegistry
    _assumeFuzzable(_wrongSender);
    vm.assume(_wrongSender != spaceRegistry);
    _mockAndExpectOutboxSender(_wrongSender);
    vm.expectRevert(IPaymentManager.InvalidL3Sender.selector);
    paymentManagerProxy.setPayer(_spaceAsTargetId(spaceA), payer);
  }

  function test_SetPayer_WhenCalledWithValidCross_chainContext() external {
    // when called with valid cross-chain context
    _mockAndExpectOutboxSender(spaceRegistry);
    // it emits PayerSet
    vm.expectEmit();
    emit IPaymentManager.PayerSet(_spaceAsTargetId(spaceA), payer);
    paymentManagerProxy.setPayer(_spaceAsTargetId(spaceA), payer);
    // it stores the payer
    assertEq(paymentManagerProxy.payers(_spaceAsTargetId(spaceA)), payer);
  }

  function test_SetPayer_WhenPayerIsUnchanged() external {
    // when payer is unchanged
    _mockAndExpectOutboxSender(spaceRegistry);
    paymentManagerProxy.setPayer(_spaceAsTargetId(spaceA), payer);
    _mockAndExpectOutboxSender(spaceRegistry);
    paymentManagerProxy.setPayer(_spaceAsTargetId(spaceA), payer);
    // it keeps the same payer
    assertEq(paymentManagerProxy.payers(_spaceAsTargetId(spaceA)), payer);
  }

  // -------- processRewards --------
  function test_ProcessRewards_WhenTargetIdIsZero(uint256 _amount) external {
    // when target id is zero
    _amount = bound(_amount, 1, 1_000_000e18);
    vm.prank(rewarderAddr);
    vm.expectRevert(IPaymentManager.InvalidTargetId.selector);
    paymentManagerProxy.processRewards(bytes32(0), _amount);
  }

  function test_ProcessRewards_WhenCallerIsNotRewarder(uint256 _amount) external {
    // when caller is not rewarder
    _amount = bound(_amount, 1, 1_000_000e18);
    vm.prank(alice);
    vm.expectRevert(IPaymentManager.OnlyRewarder.selector);
    paymentManagerProxy.processRewards(_spaceAsTargetId(spaceA), _amount);
  }

  function test_ProcessRewards_WhenCalledByRewarder(uint256 _amount) external {
    // when called by rewarder
    _amount = bound(_amount, 1e6, 100_000e18);

    // it emits RewardReceived
    vm.expectEmit();
    emit IPaymentManager.RewardReceived(_spaceAsTargetId(spaceA), _amount);
    vm.prank(rewarderAddr);
    paymentManagerProxy.processRewards(_spaceAsTargetId(spaceA), _amount);
    // it credits the space balance
    assertEq(paymentManagerProxy.totalTargetBalance(_spaceAsTargetId(spaceA)), _amount);
  }

  // -------- createPayment --------
  function test_CreatePayment_WhenTargetIdIsZero(uint256 _amount) external {
    // when target id is zero
    _amount = bound(_amount, 1, 1_000_000e18);

    vm.prank(payer);
    vm.expectRevert(IPaymentManager.InvalidTargetId.selector);
    paymentManagerProxy.createPayment(bytes32(0), recipient, _amount);
  }

  function test_CreatePayment_WhenCallerIsNotAuthorizedPayer(uint256 _amount) external {
    // when caller is not authorized payer
    _amount = bound(_amount, 1, 1_000_000e18);
    vm.prank(alice);
    vm.expectRevert(IPaymentManager.UnauthorizedPayer.selector);
    paymentManagerProxy.createPayment(_spaceAsTargetId(spaceA), recipient, _amount);
  }

  function test_CreatePayment_WhenRecipientIsZeroAddress(uint256 _amount) external {
    // when recipient is zero address
    _amount = bound(_amount, 1, 1_000_000e18);
    paymentManagerProxy.workaround_seedTargetBalanceAndPayer(_spaceAsTargetId(spaceA), _amount, payer);

    vm.prank(payer);
    vm.expectRevert(IPaymentManager.InvalidAddress.selector);
    paymentManagerProxy.createPayment(_spaceAsTargetId(spaceA), address(0), _amount);
  }

  function test_CreatePayment_WhenAmountIsZero(uint256 _balance) external {
    // when amount is zero
    _balance = bound(_balance, 1, 1_000_000e18);
    paymentManagerProxy.workaround_seedTargetBalanceAndPayer(_spaceAsTargetId(spaceA), _balance, payer);

    vm.prank(payer);
    vm.expectRevert(IPaymentManager.ZeroAmount.selector);
    paymentManagerProxy.createPayment(_spaceAsTargetId(spaceA), recipient, 0);
  }

  function test_CreatePayment_WhenInsufficientTargetBalance(uint256 _amount) external {
    // when insufficient space balance
    _amount = bound(_amount, 1, 1_000_000e18);
    paymentManagerProxy.workaround_seedTargetBalanceAndPayer(_spaceAsTargetId(spaceA), 0, payer);

    vm.prank(payer);
    vm.expectRevert(IPaymentManager.InsufficientTargetBalance.selector);
    paymentManagerProxy.createPayment(_spaceAsTargetId(spaceA), recipient, _amount);
  }

  function test_CreatePayment_WhenParametersAreValid(uint256 _amount) external {
    // when parameters are valid
    _amount = bound(_amount, 1e6, 50_000e18);
    paymentManagerProxy.workaround_seedTargetBalanceAndPayer(_spaceAsTargetId(spaceA), _amount, payer);

    uint256 _unlock = block.timestamp + paymentManagerProxy.paymentRequestDelay();
    // it emits PaymentCreated
    vm.expectEmit();
    emit IPaymentManager.PaymentCreated(0, _spaceAsTargetId(spaceA), recipient, _amount, _unlock);

    vm.prank(payer);
    uint256 _pid = paymentManagerProxy.createPayment(_spaceAsTargetId(spaceA), recipient, _amount);
    // it assigns the next incremental payment id
    assertEq(_pid, 0);
    // it reduces the space balance
    assertEq(paymentManagerProxy.totalTargetBalance(_spaceAsTargetId(spaceA)), 0);
    // it increments paymentNonce
    assertEq(paymentManagerProxy.paymentNonce(), 1);

    IPaymentManager.PaymentRequest memory _pr = paymentManagerProxy.payments(_pid);
    // it stores the payment request fields
    assertEq(_pr.targetId, _spaceAsTargetId(spaceA));
    assertEq(_pr.recipient, recipient);
    assertEq(_pr.amount, _amount);
    assertEq(_pr.unlockTime, _unlock);
  }

  // -------- slashPayment --------
  function test_SlashPayment_WhenPaymentIsMissing(uint256 _paymentId) external {
    // when payment is missing
    _paymentId = bound(_paymentId, 1, type(uint128).max);
    vm.prank(council);
    vm.expectRevert(IPaymentManager.InvalidPayment.selector);
    paymentManagerProxy.slashPayment(_paymentId);
  }

  function test_SlashPayment_WhenCalledByOwner(uint256 _amount) external {
    // when called by owner
    _amount = bound(_amount, 1e6, 50_000e18);
    bytes32 _tid = _spaceAsTargetId(spaceA);
    paymentManagerProxy.workaround_seedPaymentRecord(
      0, _tid, recipient, _amount, block.timestamp + paymentManagerProxy.paymentRequestDelay(), 1
    );

    // it emits PaymentSlashed
    vm.expectEmit();
    emit IPaymentManager.PaymentSlashed(0);
    // it sends GEO back to escrow
    _mockAndExpect(arbitrumGeoToken, abi.encodeCall(IERC20.transfer, (escrowAddr, _amount)), abi.encode(true));
    vm.prank(council);
    paymentManagerProxy.slashPayment(0);
    // it deletes the payment request
    assertEq(paymentManagerProxy.payments(0).targetId, bytes32(0));
  }

  function test_SlashPayment_WhenCalledByNon_owner(address _caller) external {
    // when called by non-owner
    vm.assume(_caller != council);
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    paymentManagerProxy.slashPayment(0);
  }

  // -------- reclaimRewards --------
  function test_ReclaimRewards_WhenTargetIdIsZero(uint256 _amount) external {
    // when target id is zero
    _amount = bound(_amount, 1, 1_000_000e18);
    vm.prank(council);
    vm.expectRevert(IPaymentManager.InvalidTargetId.selector);
    paymentManagerProxy.reclaimRewards(bytes32(0), _amount);
  }

  function test_ReclaimRewards_WhenAmountIsZero(uint256 _balance) external {
    // when amount is zero
    _balance = bound(_balance, 1, 1_000_000e18);
    paymentManagerProxy.workaround_seedTargetBalanceAndPayer(_spaceAsTargetId(spaceA), _balance, payer);

    vm.prank(council);
    vm.expectRevert(IPaymentManager.ZeroAmount.selector);
    paymentManagerProxy.reclaimRewards(_spaceAsTargetId(spaceA), 0);
  }

  function test_ReclaimRewards_WhenInsufficientTargetBalance(uint256 _amount) external {
    // when insufficient target balance
    _amount = bound(_amount, 1, 1_000_000e18);
    paymentManagerProxy.workaround_seedTargetBalanceAndPayer(_spaceAsTargetId(spaceA), 0, payer);

    vm.prank(council);
    vm.expectRevert(IPaymentManager.InsufficientTargetBalance.selector);
    paymentManagerProxy.reclaimRewards(_spaceAsTargetId(spaceA), _amount);
  }

  function test_ReclaimRewards_WhenCalledByOwner(uint256 _balance, uint256 _reclaimAmount) external {
    // when called by owner
    _balance = bound(_balance, 1e6, 50_000e18);
    _reclaimAmount = bound(_reclaimAmount, 1, _balance);
    bytes32 _tid = _spaceAsTargetId(spaceA);
    paymentManagerProxy.workaround_seedTargetBalanceAndPayer(_tid, _balance, payer);

    // it emits RewardsReclaimed
    vm.expectEmit();
    emit IPaymentManager.RewardsReclaimed(_tid, _reclaimAmount);
    // it sends GEO back to escrow
    _mockAndExpect(arbitrumGeoToken, abi.encodeCall(IERC20.transfer, (escrowAddr, _reclaimAmount)), abi.encode(true));
    vm.prank(council);
    paymentManagerProxy.reclaimRewards(_tid, _reclaimAmount);
    // it reduces the target balance
    assertEq(paymentManagerProxy.totalTargetBalance(_tid), _balance - _reclaimAmount);
  }

  function test_ReclaimRewards_WhenCalledByNon_owner(address _caller, uint256 _amount) external {
    // when called by non-owner
    _amount = bound(_amount, 1, 1_000_000e18);
    vm.assume(_caller != council);
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    paymentManagerProxy.reclaimRewards(_spaceAsTargetId(spaceA), _amount);
  }

  // -------- executePayment --------
  function test_ExecutePayment_WhenPaymentIsMissing(uint256 _paymentId) external {
    // when payment is missing
    _paymentId = bound(_paymentId, 1, type(uint128).max);
    vm.expectRevert(IPaymentManager.InvalidPayment.selector);
    paymentManagerProxy.executePayment(_paymentId);
  }

  function test_ExecutePayment_WhenUnlockTimeHasNotBeenReached(uint256 _amount) external {
    // when unlock time has not been reached
    _amount = bound(_amount, 1e6, 50_000e18);
    bytes32 _tid = _spaceAsTargetId(spaceA);
    paymentManagerProxy.workaround_seedPaymentRecord(
      0, _tid, recipient, _amount, block.timestamp + paymentManagerProxy.paymentRequestDelay() + 1, 1
    );

    vm.expectRevert(IPaymentManager.PaymentRequestLocked.selector);
    paymentManagerProxy.executePayment(0);
  }

  function test_ExecutePayment_WhenUnlockTimeHasElapsed(uint256 _amount) external {
    // when unlock time has elapsed
    _amount = bound(_amount, 1e6, 50_000e18);
    bytes32 _tid = _spaceAsTargetId(spaceA);
    paymentManagerProxy.workaround_seedPaymentRecord(0, _tid, recipient, _amount, block.timestamp, 1);

    vm.warp(block.timestamp + paymentManagerProxy.paymentRequestDelay() + 1);

    // it emits PaymentExecuted
    vm.expectEmit();
    emit IPaymentManager.PaymentExecuted(0, recipient, _amount);
    // it transfers GEO to the recipient
    _mockAndExpect(arbitrumGeoToken, abi.encodeCall(IERC20.transfer, (recipient, _amount)), abi.encode(true));
    paymentManagerProxy.executePayment(0);
    // it deletes the payment request
    assertEq(paymentManagerProxy.payments(0).targetId, bytes32(0));
  }

  // -------- typeId --------
  function test_TypeId_WhenCalled() external view {
    // when called

    // it returns the type
    assertEq(paymentManagerProxy.typeId(), keccak256('PAYMENT_MANAGER'));
  }

  // -------- name --------
  function test_Name_WhenCalled() external view {
    // when called

    // it returns the name
    assertEq(paymentManagerProxy.name(), 'PAYMENT_MANAGER');
  }

  // -------- version --------
  function test_Version_WhenCalled() external view {
    // when called

    // it returns semantic version
    assertEq(paymentManagerProxy.version(), '1.0.0');
  }

  // -------- _authorizeUpgrade --------
  function test__authorizeUpgrade_WhenCalledByOwner() external {
    // when called by owner
    address newImplementation = address(new PaymentManager());
    vm.prank(council);
    // it authorizes the upgrade
    paymentManagerProxy.upgradeToAndCall(newImplementation, '');
  }

  function test__authorizeUpgrade_WhenCalledByNon_owner(address _caller) external {
    // when called by non-owner
    vm.assume(_caller != council);
    address newImplementation = address(new PaymentManager());
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    paymentManagerProxy.upgradeToAndCall(newImplementation, '');
  }

  function _spaceAsTargetId(address _space) internal pure returns (bytes32 _targetId) {
    _targetId = bytes32(uint256(uint160(_space)));
  }

  function _mockAndExpectOutboxSender(address _sender) internal {
    _mockAndExpect(outboxAddr, abi.encodeCall(IOutbox.l2ToL1Sender, ()), abi.encode(_sender));
  }
}
