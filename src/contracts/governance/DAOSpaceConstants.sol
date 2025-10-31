// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {IDAOSpaceConstants} from 'interfaces/governance/IDAOSpaceConstants.sol';

/**
 * @title DAO Space Constants
 * @notice Contains constants used by the DAO Space contract for governance and access control
 */
contract DAOSpaceConstants is IDAOSpaceConstants {
  /// @inheritdoc IDAOSpaceConstants
  uint256 public constant RATIO_BASE = 10e6;

  /// @inheritdoc IDAOSpaceConstants
  bytes32 public constant EDITOR = keccak256('EDITOR');

  /// @inheritdoc IDAOSpaceConstants
  bytes32 public constant MEMBER = keccak256('MEMBER');

  /// @inheritdoc IDAOSpaceConstants
  bytes32 public constant DAO = keccak256('DAO');

  /**
   * @notice Action constant: Create a governance proposal
   * @dev When this action is used, the topic should be empty and the data should contain:
   * bytes(abi.encode(bytes(uri), Action[], VoteOption)) - URI + Onchain Operations + Vote option
   * @inheritdoc IDAOSpaceConstants
   */
  bytes32 public constant CREATE_PROPOSAL = keccak256('CREATE_PROPOSAL');

  /**
   * @notice Action constant: Vote on a proposal
   * @dev When this action is used, the topic should be empty and the data should contain:
   * bytes(abi.encode(uint256(proposalId), VoteOption))
   * Vote Options: 0 - None, 1 - Abstain, 2 - Yes, 3 - No
   * @inheritdoc IDAOSpaceConstants
   */
  bytes32 public constant VOTE = keccak256('VOTE');

  /**
   * @notice Action constant: Execute a proposal
   * @dev When this action is used, the topic should be empty and the data should contain:
   * bytes(abi.encode(uint256(proposalId)))
   * @inheritdoc IDAOSpaceConstants
   */
  bytes32 public constant EXECUTE_PROPOSAL = keccak256('EXECUTE_PROPOSAL');

  /**
   * @notice Action constant: Leave the space
   * @dev When this action is used, it allows a member or editor to remove themselves from the space
   * @inheritdoc IDAOSpaceConstants
   */
  bytes32 public constant LEAVE = keccak256('LEAVE');
}
