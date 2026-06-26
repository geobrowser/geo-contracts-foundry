// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {IEscrow} from 'interfaces/L2/IEscrow.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title Escrow
 * @notice Simple custody contract for GEO incentives; council funds it via ERC20 transfer; only the rewarder set at init may pull
 * @custom:security WARNING: This contract has not been audited, and may contain bugs.
 */
contract Escrow is OwnableUpgradeable, UUPSUpgradeable, IEscrow {
  using SafeERC20 for IERC20;

  /**
   * @notice ERC-7201 namespaced storage slot for the Escrow contract
   * @custom:storage-location erc7201:geo.storage.Escrow
   * @dev Computed with: keccak256(abi.encode(uint256(keccak256("geo.storage.Escrow")) - 1)) & ~bytes32(uint256(0xff))
   */
  bytes32 internal constant _ESCROW_STORAGE_LOCATION =
    0xeb57782b9fcbf19d652848ed1d4b5df43246de414d15919c053af4c61a210b00;

  /**
   * @notice Constructor
   * @custom:oz-upgrades-unsafe-allow constructor
   */
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IEscrow
  function initialize(EscrowInitializationParams calldata _initParams) external virtual initializer {
    if (_initParams.arbitrumGeoToken == address(0) || _initParams.rewarder == address(0)) revert InvalidAddress();

    __Ownable_init(_initParams.council);
    __UUPSUpgradeable_init();

    EscrowStorage storage $_ = _getEscrowStorage();
    $_.arbitrumGeoToken = IERC20(_initParams.arbitrumGeoToken);
    $_.rewarder = _initParams.rewarder;
  }

  /// @inheritdoc IEscrow
  function pull(address _to, uint256 _amount) external virtual {
    EscrowStorage storage $_ = _getEscrowStorage();
    if (msg.sender != $_.rewarder) revert OnlyRewarder();
    $_.arbitrumGeoToken.safeTransfer(_to, _amount);
  }

  /// @inheritdoc IEscrow
  function arbitrumGeoToken() external view returns (IERC20 _arbitrumGeoToken) {
    _arbitrumGeoToken = _getEscrowStorage().arbitrumGeoToken;
  }

  /// @inheritdoc IEscrow
  function rewarder() external view returns (address _rewarder) {
    _rewarder = _getEscrowStorage().rewarder;
  }

  /// @inheritdoc ISemver
  function typeId() public pure virtual returns (bytes32 _type) {
    _type = keccak256(bytes(name()));
  }

  /// @inheritdoc ISemver
  function name() public pure virtual returns (string memory _name) {
    _name = 'ESCROW';
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
   * @notice Returns the ERC-7201 namespaced storage pointer for Escrow
   * @return $_ Namespaced storage for Escrow
   * @custom:storage-location erc7201:geo.storage.Escrow
   */
  function _getEscrowStorage() internal pure returns (EscrowStorage storage $_) {
    assembly {
      $_.slot := _ESCROW_STORAGE_LOCATION
    }
  }
}
