// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {IDAOSpaceConstants} from 'interfaces/governance/IDAOSpaceConstants.sol';

/**
 * @title DAO Space Constants
 * @notice Contains constants used by the DAO Space contract for governance and access control
 */
abstract contract DAOSpaceConstants is IDAOSpaceConstants {
  /// @inheritdoc IDAOSpaceConstants
  uint256 public constant RATIO_BASE = 10e6;

  /// @inheritdoc IDAOSpaceConstants
  bytes32 public constant EDITOR = keccak256('EDITOR');

  /// @inheritdoc IDAOSpaceConstants
  bytes32 public constant MEMBER = keccak256('MEMBER');

  /// @inheritdoc IDAOSpaceConstants
  bytes32 public constant DAO = keccak256('DAO');

  /// @inheritdoc IDAOSpaceConstants
  bytes32 public constant CREATE_PROPOSAL = keccak256('CREATE_PROPOSAL');

  /// @inheritdoc IDAOSpaceConstants
  bytes32 public constant VOTE = keccak256('VOTE');

  /// @inheritdoc IDAOSpaceConstants
  bytes32 public constant EXECUTE_PROPOSAL = keccak256('EXECUTE_PROPOSAL');

  /// @inheritdoc IDAOSpaceConstants
  bytes32 public constant LEAVE = keccak256('LEAVE');
}
