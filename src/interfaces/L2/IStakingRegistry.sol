// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title IStakingRegistry
 * @notice Council-owned registry of incentive allocation targets and deterministic target id derivation from space and topic identifiers
 */
interface IStakingRegistry is ISemver {
  /**
   * @notice Kind of allocation target keyed by a derived `bytes32` id
   * @param Null Empty sentinel (enum value 0); unset `targets` entries read as `Null` with `tActive == false`
   * @param Space Space targets use the full `bytes32` space key as the canonical target id
   * @param Topic Topic targets use the high 128 bits of a `bytes32` topic id (`topicId >> 128`) as the canonical target id, keeping bit domains separable from spaces
   */
  enum TargetType {
    Null,
    Space,
    Topic
  }

  /**
   * @notice Onchain record for a council-configured allocation target
   * @param tType Classification of the target (`Null`, `Space`, or `Topic`)
   * @param tActive Whether the target is active for allocations (inactive targets are not valid for incentives)
   */
  struct Target {
    TargetType tType;
    bool tActive;
  }

  /**
   * @notice Parameters required for initializing the StakingRegistry contract
   * @param council Address of the GEO council (owner) that may configure targets
   */
  struct StakingRegistryInitializationParams {
    address council;
  }

  /**
   * @notice ERC-7201 namespaced storage for StakingRegistry.
   * @param targets Mapping of target ids to their council-configured details
   * @custom:storage-location erc7201:geo.storage.StakingRegistry
   */
  struct StakingRegistryStorage {
    mapping(bytes32 _targetId => Target _target) targets;
  }

  /**
   * @notice Emitted when a target is created or updated
   * @param _targetId Canonical target id used across incentives
   * @param _tType Target classification
   * @param _tActive Whether the target is active for allocations
   */
  event TargetSet(bytes32 indexed _targetId, TargetType indexed _tType, bool indexed _tActive);

  /// @notice Thrown when `TargetType.Null` is set with `tActive == true`; Null is reserved for unset entries and must not be a valid allocation target
  error NullTargetCannotBeActive();

  /// @notice Thrown when `_targetId == bytes32(0)`; zero is reserved as the unset sentinel and must not be registered
  error InvalidTargetId();

  /**
   * @notice Initializes the StakingRegistry contract
   * @dev Can only be called once during proxy deployment.
   * @param _initParams Initialization parameters
   */
  function initialize(StakingRegistryInitializationParams calldata _initParams) external;

  /**
   * @notice Sets or updates a target record
   * @dev Callable only by the owner (council).
   * @param _targetId Canonical target id
   * @param _target Target classification and active flag
   * @custom:reverts InvalidTargetId when `_targetId == bytes32(0)`;
   *   NullTargetCannotBeActive when `_target.tType == TargetType.Null` and `_target.tActive`
   */
  function setTarget(bytes32 _targetId, Target calldata _target) external;

  /**
   * @notice Returns the stored target record for a canonical id
   * @param _targetId Canonical target id
   * @return _target Stored details; unset ids read as `(TargetType.Null, false)`
   */
  function targets(bytes32 _targetId) external view returns (Target memory _target);

  /**
   * @notice Derives the canonical `bytes32` target id from a space or topic identifier
   * @dev For `_isTopic == false`, `_spaceOrTopicId` is returned unchanged (callers must supply the same `bytes32` encoding used everywhere else). For `_isTopic == true`, the high 128 bits of `_spaceOrTopicId` are taken (`>> 128`), matching the topic convention discussed on the incentives design thread
   * @param _spaceOrTopicId Full-width id; interpretation depends on `_isTopic`
   * @param _isTopic When true, treat `_spaceOrTopicId` as a topic id and fold its high 128 bits; when false, treat it as a space id word
   * @return _targetId Canonical target id
   */
  function getTargetId(bytes32 _spaceOrTopicId, bool _isTopic) external pure returns (bytes32 _targetId);
}
