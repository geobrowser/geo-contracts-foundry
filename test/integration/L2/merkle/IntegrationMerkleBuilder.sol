// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Hashes} from '@openzeppelin/contracts/utils/cryptography/Hashes.sol';

/**
 * @title IntegrationMerkleBuilder
 * @notice Builds OZ `SimpleMerkleTree`-compatible roots and proofs for integration tests
 * @dev Matches `@openzeppelin/merkle-tree` defaults: pre-hashed leaves, sorted by leaf hash, commutative node hash
 */
library IntegrationMerkleBuilder {
  struct LeafEntry {
    bytes32 hash;
    uint256 originalIndex;
  }

  /// @notice Returns the Merkle root for pre-hashed `_leaves`
  function root(bytes32[] memory _leaves) internal pure returns (bytes32 _root) {
    bytes32[] memory _sorted = _sortedLeaves(_leaves);
    _root = _treeRoot(_sorted);
  }

  /// @notice Returns a proof for `_leafIndex` in the original `_leaves` array order
  function proof(bytes32[] memory _leaves, uint256 _leafIndex) internal pure returns (bytes32[] memory _proof) {
    (bytes32[] memory _sorted, uint256[] memory _treeIndices) = _prepare(_leaves);
    _proof = _treeProof(_sorted, _treeIndices[_leafIndex]);
  }

  function _prepare(bytes32[] memory _leaves)
    private
    pure
    returns (bytes32[] memory _sorted, uint256[] memory _treeIndices)
  {
    uint256 _n = _leaves.length;
    LeafEntry[] memory _entries = new LeafEntry[](_n);
    for (uint256 _i = 0; _i < _n; _i++) {
      _entries[_i] = LeafEntry({hash: _leaves[_i], originalIndex: _i});
    }
    _sortEntries(_entries);

    _sorted = new bytes32[](_n);
    _treeIndices = new uint256[](_n);
    uint256 _treeLength = 2 * _n - 1;
    for (uint256 _leafPos = 0; _leafPos < _n; _leafPos++) {
      _sorted[_leafPos] = _entries[_leafPos].hash;
      _treeIndices[_entries[_leafPos].originalIndex] = _treeLength - 1 - _leafPos;
    }
  }

  function _sortedLeaves(bytes32[] memory _leaves) private pure returns (bytes32[] memory _sorted) {
    (_sorted,) = _prepare(_leaves);
  }

  function _treeRoot(bytes32[] memory _sortedLeaves) private pure returns (bytes32 _root) {
    bytes32[] memory _tree = _buildTree(_sortedLeaves);
    _root = _tree[0];
  }

  function _treeProof(
    bytes32[] memory _sortedLeaves,
    uint256 _treeIndex
  ) private pure returns (bytes32[] memory _proof) {
    bytes32[] memory _tree = _buildTree(_sortedLeaves);

    uint256 _depth;
    for (uint256 _idx = _treeIndex; _idx > 0; _idx = (_idx - 1) / 2) {
      _depth++;
    }

    _proof = new bytes32[](_depth);
    uint256 _proofIndex;
    for (uint256 _idx = _treeIndex; _idx > 0; _idx = (_idx - 1) / 2) {
      uint256 _sibling = _idx % 2 == 0 ? _idx - 1 : _idx + 1;
      _proof[_proofIndex++] = _tree[_sibling];
    }
  }

  function _buildTree(bytes32[] memory _sortedLeaves) private pure returns (bytes32[] memory _tree) {
    uint256 _n = _sortedLeaves.length;
    _tree = new bytes32[](2 * _n - 1);

    for (uint256 _i = 0; _i < _n; _i++) {
      _tree[_tree.length - 1 - _i] = _sortedLeaves[_i];
    }

    if (_n == 1) {
      return _tree;
    }

    for (uint256 _i = _tree.length - 1 - _n;; _i--) {
      _tree[_i] = Hashes.commutativeKeccak256(_tree[2 * _i + 1], _tree[2 * _i + 2]);
      if (_i == 0) break;
    }
  }

  function _sortEntries(LeafEntry[] memory _entries) private pure {
    uint256 _n = _entries.length;
    for (uint256 _i = 0; _i < _n; _i++) {
      for (uint256 _j = _i + 1; _j < _n; _j++) {
        if (_entries[_j].hash < _entries[_i].hash) {
          LeafEntry memory _tmp = _entries[_i];
          _entries[_i] = _entries[_j];
          _entries[_j] = _tmp;
        }
      }
    }
  }
}
