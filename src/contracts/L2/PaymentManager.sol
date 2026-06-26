// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {IOutbox} from 'interfaces/L2/IOutbox.sol';
import {IPaymentManager} from 'interfaces/L2/IPaymentManager.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title PaymentManager
 * @notice Manages GEO token payments to Spaces with a configurable request delay and council oversight
 * @custom:security WARNING: This contract has not been audited, and may contain bugs.
 */
contract PaymentManager is OwnableUpgradeable, UUPSUpgradeable, IPaymentManager {
  using SafeERC20 for IERC20;
  /**
   * @notice ERC-7201 namespaced storage slot for the PaymentManager contract
   * @custom:storage-location erc7201:geo.storage.PaymentManager
   * @dev Computed with: keccak256(abi.encode(uint256(keccak256("geo.storage.PaymentManager")) - 1)) & ~bytes32(uint256(0xff))
   */
  bytes32 internal constant _PAYMENT_MANAGER_STORAGE_LOCATION =
    0x8592aeb4b2f0a2506ac60fc82281ae7f8c16ad75338c52aa379e7d4ca22cb600;

  /**
   * @notice Constructor
   * @custom:oz-upgrades-unsafe-allow constructor
   */
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IPaymentManager
  function initialize(PaymentManagerInitializationParams calldata _initParams) external virtual initializer {
    if (
      _initParams.arbitrumGeoToken == address(0) || _initParams.outbox == address(0)
        || _initParams.rewarder == address(0) || _initParams.escrow == address(0)
        || _initParams.spaceRegistry == address(0)
    ) {
      revert InvalidAddress();
    }

    __Ownable_init(_initParams.council);
    __UUPSUpgradeable_init();

    PaymentManagerStorage storage $_ = _getPaymentManagerStorage();
    $_.arbitrumGeoToken = IERC20(_initParams.arbitrumGeoToken);
    $_.outbox = IOutbox(_initParams.outbox);
    $_.rewarder = _initParams.rewarder;
    $_.escrow = _initParams.escrow;
    $_.spaceRegistry = _initParams.spaceRegistry;

    _setPaymentRequestDelay(_initParams.paymentRequestDelay);
  }

  /// @inheritdoc IPaymentManager
  function setPaymentRequestDelay(uint256 _paymentRequestDelay) external virtual onlyOwner {
    _setPaymentRequestDelay(_paymentRequestDelay);
  }

  /// @inheritdoc IPaymentManager
  function setPayer(bytes32 _targetId, address _payer) external virtual {
    if (_targetId == bytes32(0)) revert InvalidTargetId();

    PaymentManagerStorage storage $_ = _getPaymentManagerStorage();
    address _l3Sender = $_.outbox.l2ToL1Sender();
    if (_l3Sender != $_.spaceRegistry) revert InvalidL3Sender();

    address _oldPayer = $_.payers[_targetId];
    if (_oldPayer == _payer) return;

    $_.payers[_targetId] = _payer;

    emit PayerSet(_targetId, _payer);
  }

  /// @inheritdoc IPaymentManager
  function processRewards(bytes32 _targetId, uint256 _amount) external virtual {
    if (_targetId == bytes32(0)) revert InvalidTargetId();

    PaymentManagerStorage storage $_ = _getPaymentManagerStorage();
    if (msg.sender != $_.rewarder) revert OnlyRewarder();

    $_.totalTargetBalance[_targetId] += _amount;

    emit RewardReceived(_targetId, _amount);
  }

  /// @inheritdoc IPaymentManager
  function createPayment(
    bytes32 _targetId,
    address _recipient,
    uint256 _amount
  ) external virtual returns (uint256 _paymentId) {
    if (_targetId == bytes32(0)) revert InvalidTargetId();

    PaymentManagerStorage storage $_ = _getPaymentManagerStorage();
    if (msg.sender != $_.payers[_targetId]) revert UnauthorizedPayer();
    if (_recipient == address(0)) revert InvalidAddress();
    if (_amount == 0) revert ZeroAmount();
    if ($_.totalTargetBalance[_targetId] < _amount) revert InsufficientTargetBalance();

    uint256 _unlockTime = block.timestamp + $_.paymentRequestDelay;

    _paymentId = $_.paymentNonce++;
    $_.payments[_paymentId] =
      PaymentRequest({targetId: _targetId, recipient: _recipient, amount: _amount, unlockTime: _unlockTime});

    $_.totalTargetBalance[_targetId] -= _amount;

    emit PaymentCreated(_paymentId, _targetId, _recipient, _amount, _unlockTime);
  }

  /// @inheritdoc IPaymentManager
  function slashPayment(uint256 _paymentId) external virtual onlyOwner {
    PaymentManagerStorage storage $_ = _getPaymentManagerStorage();
    PaymentRequest memory _payment = $_.payments[_paymentId];

    if (_payment.targetId == bytes32(0)) revert InvalidPayment();

    uint256 _amount = _payment.amount;

    delete $_.payments[_paymentId];

    $_.arbitrumGeoToken.safeTransfer($_.escrow, _amount);

    emit PaymentSlashed(_paymentId);
  }

  /// @inheritdoc IPaymentManager
  function reclaimRewards(bytes32 _targetId, uint256 _amount) external virtual onlyOwner {
    if (_targetId == bytes32(0)) revert InvalidTargetId();
    if (_amount == 0) revert ZeroAmount();

    PaymentManagerStorage storage $_ = _getPaymentManagerStorage();
    if ($_.totalTargetBalance[_targetId] < _amount) revert InsufficientTargetBalance();

    $_.totalTargetBalance[_targetId] -= _amount;

    $_.arbitrumGeoToken.safeTransfer($_.escrow, _amount);

    emit RewardsReclaimed(_targetId, _amount);
  }

  /// @inheritdoc IPaymentManager
  function executePayment(uint256 _paymentId) external virtual {
    PaymentManagerStorage storage $_ = _getPaymentManagerStorage();
    PaymentRequest memory _payment = $_.payments[_paymentId];

    if (_payment.targetId == bytes32(0)) revert InvalidPayment();
    if (block.timestamp < _payment.unlockTime) revert PaymentRequestLocked();

    address _recipient = _payment.recipient;
    uint256 _amount = _payment.amount;

    delete $_.payments[_paymentId];

    $_.arbitrumGeoToken.safeTransfer(_recipient, _amount);

    emit PaymentExecuted(_paymentId, _recipient, _amount);
  }

  /// @inheritdoc IPaymentManager
  function arbitrumGeoToken() public view returns (IERC20 _arbitrumGeoToken) {
    _arbitrumGeoToken = _getPaymentManagerStorage().arbitrumGeoToken;
  }

  /// @inheritdoc IPaymentManager
  function outbox() public view returns (IOutbox _outbox) {
    _outbox = _getPaymentManagerStorage().outbox;
  }

  /// @inheritdoc IPaymentManager
  function rewarder() public view returns (address _rewarder) {
    _rewarder = _getPaymentManagerStorage().rewarder;
  }

  /// @inheritdoc IPaymentManager
  function escrow() public view returns (address _escrow) {
    _escrow = _getPaymentManagerStorage().escrow;
  }

  /// @inheritdoc IPaymentManager
  function spaceRegistry() public view returns (address _spaceRegistry) {
    _spaceRegistry = _getPaymentManagerStorage().spaceRegistry;
  }

  /// @inheritdoc IPaymentManager
  function paymentRequestDelay() public view returns (uint256 _paymentRequestDelay) {
    _paymentRequestDelay = _getPaymentManagerStorage().paymentRequestDelay;
  }

  /// @inheritdoc IPaymentManager
  function paymentNonce() public view returns (uint256 _paymentNonce) {
    _paymentNonce = _getPaymentManagerStorage().paymentNonce;
  }

  /// @inheritdoc IPaymentManager
  function totalTargetBalance(bytes32 _targetId) public view returns (uint256 _balance) {
    _balance = _getPaymentManagerStorage().totalTargetBalance[_targetId];
  }

  /// @inheritdoc IPaymentManager
  function payers(bytes32 _targetId) public view returns (address _payer) {
    _payer = _getPaymentManagerStorage().payers[_targetId];
  }

  /// @inheritdoc IPaymentManager
  function payments(uint256 _paymentId) public view returns (PaymentRequest memory _payment) {
    _payment = _getPaymentManagerStorage().payments[_paymentId];
  }

  /// @inheritdoc ISemver
  function typeId() public pure virtual returns (bytes32 _type) {
    _type = keccak256(bytes(name()));
  }

  /// @inheritdoc ISemver
  function name() public pure virtual returns (string memory _name) {
    _name = 'PAYMENT_MANAGER';
  }

  /// @inheritdoc ISemver
  function version() public pure virtual returns (string memory _version) {
    _version = '1.0.0';
  }

  /**
   * @inheritdoc UUPSUpgradeable
   * @dev Function that should revert when msg.sender is not authorized to upgrade the contract
   */
  function _authorizeUpgrade(
    address /* _newImplementation */
  ) internal virtual override onlyOwner {}

  /**
   * @notice Persists the payment request delay and emits the corresponding event
   * @param _paymentRequestDelay The new delay in seconds
   */
  function _setPaymentRequestDelay(uint256 _paymentRequestDelay) internal virtual {
    _getPaymentManagerStorage().paymentRequestDelay = _paymentRequestDelay;
    emit PaymentRequestDelaySet(_paymentRequestDelay);
  }

  /**
   * @notice Returns the ERC-7201 namespaced storage pointer for PaymentManager
   * @return $_ Namespaced storage for PaymentManager
   * @custom:storage-location erc7201:geo.storage.PaymentManager
   */
  function _getPaymentManagerStorage() internal pure returns (PaymentManagerStorage storage $_) {
    assembly {
      $_.slot := _PAYMENT_MANAGER_STORAGE_LOCATION
    }
  }
}
