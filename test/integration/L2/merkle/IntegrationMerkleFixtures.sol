// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Test} from 'forge-std/Test.sol';

import {IntegrationMerkleBuilder} from 'test/integration/L2/merkle/IntegrationMerkleBuilder.sol';

/**
 * @title IntegrationMerkleFixtures
 * @notice Rewarder Merkle roots/proofs for integration tests, built in Solidity at runtime
 * @dev Leaf layout matches `Rewarder._claimSingleUserReward` / `_claimSingleTargetReward`.
 * @dev `makeAddr` labels on `_userRewardsClaimer*` and `integration_space_id_*` are fixture constants: changing a
 *      label changes the derived address, Merkle leaves, and published roots.
 */
abstract contract IntegrationMerkleFixtures is Test {
  using IntegrationMerkleBuilder for bytes32[];

  error IndexOutOfBounds();

  uint256 internal constant _USER_REWARDS_EPOCH = 77_777;
  uint256 internal constant _TARGET_REWARDS_EPOCH = 88_888;
  uint256 internal constant _USER_REWARDS_CLAIM_COUNT = 4;
  uint256 internal constant _TARGET_REWARDS_CLAIM_COUNT = 4;
  uint256 internal constant _USER_REWARDS_PRIMARY_INDEX = 0;
  uint256 internal constant _TARGET_REWARDS_PRIMARY_INDEX = 0;

  uint256 internal constant _USER_REWARDS_AMOUNT_0 = 3000e18;
  uint256 internal constant _USER_REWARDS_AMOUNT_1 = 5000e18;
  uint256 internal constant _USER_REWARDS_AMOUNT_2 = 7000e18;
  uint256 internal constant _USER_REWARDS_AMOUNT_3 = 11_000e18;

  uint256 internal constant _TARGET_REWARDS_AMOUNT_0 = 40_000e18;
  uint256 internal constant _TARGET_REWARDS_AMOUNT_1 = 60_000e18;
  uint256 internal constant _TARGET_REWARDS_AMOUNT_2 = 80_000e18;
  uint256 internal constant _TARGET_REWARDS_AMOUNT_3 = 20_000e18;

  address internal _userRewardsClaimer0 = makeAddr('integration_reward_claimer_0');
  address internal _userRewardsClaimer1 = makeAddr('integration_reward_claimer_1');
  address internal _userRewardsClaimer2 = makeAddr('integration_reward_claimer_2');
  address internal _userRewardsClaimer3 = makeAddr('integration_reward_claimer_3');

  bytes32 internal _targetRewardsSpaceId0 = bytes32(uint256(uint160(makeAddr('integration_space_id_0'))));
  bytes32 internal _targetRewardsSpaceId1 = bytes32(uint256(uint160(makeAddr('integration_space_id_1'))));
  bytes32 internal _targetRewardsSpaceId2 = bytes32(uint256(uint160(makeAddr('integration_space_id_2'))));
  bytes32 internal _targetRewardsSpaceId3 = bytes32(uint256(uint160(makeAddr('integration_space_id_3'))));

  /// @dev Space id encoded in every user-reward Merkle leaf; aliases `_targetRewardsSpaceId0`.
  bytes32 internal _userRewardsSpaceId = _targetRewardsSpaceId0;

  function _userRewardsRoot() internal returns (bytes32 _root) {
    _root = _userRewardsLeaves().root();
  }

  function _userRewardsTotalClaimable() internal pure returns (uint256 _total) {
    _total = _USER_REWARDS_AMOUNT_0 + _USER_REWARDS_AMOUNT_1 + _USER_REWARDS_AMOUNT_2 + _USER_REWARDS_AMOUNT_3;
  }

  function _userRewardsClaimAt(uint256 _index)
    internal
    returns (address _claimer, uint256 _amount, bytes32[] memory _proof)
  {
    (_claimer, _amount) = _userRewardsClaimData(_index);
    _proof = _userRewardsLeaves().proof(_index);
  }

  function _targetRewardsRoot() internal returns (bytes32 _root) {
    _root = _targetRewardsLeaves().root();
  }

  function _targetRewardsTotalClaimable() internal pure returns (uint256 _total) {
    _total = _TARGET_REWARDS_AMOUNT_0 + _TARGET_REWARDS_AMOUNT_1 + _TARGET_REWARDS_AMOUNT_2 + _TARGET_REWARDS_AMOUNT_3;
  }

  function _targetRewardsClaimAt(uint256 _index)
    internal
    returns (bytes32 _targetId, uint256 _amount, bytes32[] memory _proof)
  {
    (_targetId, _amount) = _targetRewardsClaimData(_index);
    _proof = _targetRewardsLeaves().proof(_index);
  }

  function _epochsAmountsProofs(
    uint256 _epoch,
    uint256 _amount,
    bytes32[] memory _proof
  ) internal pure returns (uint256[] memory _epochs, uint256[] memory _amounts, bytes32[][] memory _proofs) {
    _epochs = new uint256[](1);
    _epochs[0] = _epoch;
    _amounts = new uint256[](1);
    _amounts[0] = _amount;
    _proofs = new bytes32[][](1);
    _proofs[0] = _proof;
  }

  function _userRewardLeaf(
    address _claimer,
    bytes32 _targetId,
    uint256 _epoch,
    uint256 _amount
  ) internal pure returns (bytes32 _leaf) {
    _leaf = keccak256(abi.encodePacked(_claimer, _targetId, _epoch, _amount));
  }

  function _targetRewardLeaf(bytes32 _targetId, uint256 _epoch, uint256 _amount) internal pure returns (bytes32 _leaf) {
    _leaf = keccak256(abi.encodePacked(_targetId, _epoch, _amount));
  }

  function _userRewardsLeaves() internal returns (bytes32[] memory _leaves) {
    _leaves = new bytes32[](_USER_REWARDS_CLAIM_COUNT);
    bytes32 _targetId = _userRewardsSpaceId;
    uint256 _epoch = _USER_REWARDS_EPOCH;

    for (uint256 _i = 0; _i < _USER_REWARDS_CLAIM_COUNT; _i++) {
      (address _claimer, uint256 _amount) = _userRewardsClaimData(_i);
      _leaves[_i] = _userRewardLeaf(_claimer, _targetId, _epoch, _amount);
    }
  }

  function _targetRewardsLeaves() internal returns (bytes32[] memory _leaves) {
    _leaves = new bytes32[](_TARGET_REWARDS_CLAIM_COUNT);
    uint256 _epoch = _TARGET_REWARDS_EPOCH;

    for (uint256 _i = 0; _i < _TARGET_REWARDS_CLAIM_COUNT; _i++) {
      (bytes32 _targetId, uint256 _amount) = _targetRewardsClaimData(_i);
      _leaves[_i] = _targetRewardLeaf(_targetId, _epoch, _amount);
    }
  }

  function _userRewardsClaimData(uint256 _index) internal view returns (address _claimer, uint256 _amount) {
    if (_index == 0) return (_userRewardsClaimer0, _USER_REWARDS_AMOUNT_0);
    if (_index == 1) return (_userRewardsClaimer1, _USER_REWARDS_AMOUNT_1);
    if (_index == 2) return (_userRewardsClaimer2, _USER_REWARDS_AMOUNT_2);
    if (_index == 3) return (_userRewardsClaimer3, _USER_REWARDS_AMOUNT_3);
    revert IndexOutOfBounds();
  }

  function _targetRewardsClaimData(uint256 _index) internal view returns (bytes32 _targetId, uint256 _amount) {
    if (_index == 0) return (_targetRewardsSpaceId0, _TARGET_REWARDS_AMOUNT_0);
    if (_index == 1) return (_targetRewardsSpaceId1, _TARGET_REWARDS_AMOUNT_1);
    if (_index == 2) return (_targetRewardsSpaceId2, _TARGET_REWARDS_AMOUNT_2);
    if (_index == 3) return (_targetRewardsSpaceId3, _TARGET_REWARDS_AMOUNT_3);
    revert IndexOutOfBounds();
  }
}
