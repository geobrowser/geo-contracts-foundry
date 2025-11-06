// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

/**
 * @title DAO Space Constants Interface
 * @notice Contains constants used by the DAO Space contract for governance and access control
 */
interface IDAOSpaceConstants {
  /**
   * @notice Returns the ratio base used for percentage calculations
   * @return _ratioBase The ratio base (10^6)
   */
  function RATIO_BASE() external view returns (uint256 _ratioBase);

  /**
   * @notice Returns the editor role identifier
   * @return _editor The editor role identifier
   */
  function EDITOR() external view returns (bytes32 _editor);

  /**
   * @notice Returns the member role identifier
   * @return _member The member role identifier
   */
  function MEMBER() external view returns (bytes32 _member);

  /**
   * @notice Returns the DAO role identifier
   * @return _dao The DAO role identifier
   */
  function DAO() external view returns (bytes32 _dao);

  /**
   * @notice Returns the action constant for creating a governance proposal
   * @return _createProposal The create proposal action constant
   * @dev When this action is used, the topic should be empty and the data should contain:
   * bytes(abi.encode(bytes(uri), Action[])) - URI + Onchain Operations
   */
  function CREATE_PROPOSAL() external view returns (bytes32 _createProposal);

  /**
   * @notice Returns the action constant for voting on a proposal
   * @return _vote The vote action constant
   * @dev When this action is used, the topic should be empty and the data should contain:
   * bytes(abi.encode(uint256(proposalId), VoteOption))
   * Vote Options: 0 - None, 1 - Abstain, 2 - Yes, 3 - No
   */
  function VOTE() external view returns (bytes32 _vote);

  /**
   * @notice Returns the action constant for executing a proposal
   * @return _executeProposal The execute proposal action constant
   * @dev When this action is used, the topic should be empty and the data should contain:
   * bytes(abi.encode(uint256(proposalId)))
   */
  function EXECUTE_PROPOSAL() external view returns (bytes32 _executeProposal);

  /**
   * @notice Returns the action constant for leaving the space
   * @return _leave The leave action constant
   */
  function LEAVE() external view returns (bytes32 _leave);
}
