// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {IStakingRegistry} from 'interfaces/L2/IStakingRegistry.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title StakingRegistry
 * @notice Council-owned upgradeable registry of incentive allocation targets and helpers to derive canonical target ids
 * @custom:security WARNING: This contract has not been audited, and may contain bugs.
 */
contract StakingRegistry is OwnableUpgradeable, UUPSUpgradeable, IStakingRegistry {
  /**
   * @notice ERC-7201 namespaced storage slot for the StakingRegistry contract
   * @custom:storage-location erc7201:geo.storage.StakingRegistry
   * @dev Computed with: keccak256(abi.encode(uint256(keccak256("geo.storage.StakingRegistry")) - 1)) & ~bytes32(uint256(0xff))
   */
  bytes32 internal constant _STAKING_REGISTRY_STORAGE_LOCATION =
    0x523fa458529b8edc7267ee9f526e422b0928963ebfccadd65d7b3398f4ebe200;

  /**
   * @notice Constructor
   * @custom:oz-upgrades-unsafe-allow constructor
   */
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IStakingRegistry
  function initialize(StakingRegistryInitializationParams calldata _initParams) external virtual initializer {
    __Ownable_init(_initParams.council);
    __UUPSUpgradeable_init();
  }

  /// @inheritdoc IStakingRegistry
  function setTarget(bytes32 _targetId, Target calldata _target) external virtual onlyOwner {
    if (_targetId == bytes32(0)) revert InvalidTargetId();
    if (_target.tType == TargetType.Null && _target.tActive) revert NullTargetCannotBeActive();
    _getStakingRegistryStorage().targets[_targetId] = _target;
    emit TargetSet(_targetId, _target.tType, _target.tActive);
  }

  /// @inheritdoc IStakingRegistry
  function targets(bytes32 _targetId) public view returns (Target memory _target) {
    _target = _getStakingRegistryStorage().targets[_targetId];
  }

  /// @inheritdoc IStakingRegistry
  function getTargetId(bytes32 _spaceOrTopicId, bool _isTopic) public pure virtual returns (bytes32 _targetId) {
    _targetId = _isTopic ? _spaceOrTopicId >> 128 : _spaceOrTopicId;
  }

  /// @inheritdoc ISemver
  function typeId() public pure virtual returns (bytes32 _type) {
    _type = keccak256(bytes(name()));
  }

  /// @inheritdoc ISemver
  function name() public pure virtual returns (string memory _name) {
    _name = 'STAKING_REGISTRY';
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
   * @notice Returns the ERC-7201 namespaced storage pointer for StakingRegistry
   * @return $_ Namespaced storage for StakingRegistry
   * @custom:storage-location erc7201:geo.storage.StakingRegistry
   */
  function _getStakingRegistryStorage() internal pure returns (StakingRegistryStorage storage $_) {
    assembly {
      $_.slot := _STAKING_REGISTRY_STORAGE_LOCATION
    }
  }
}
