// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Ghost state for invariant testing
abstract contract GhostState {
  enum ActorType {
    Unknown, // 0 - default for unmapped addresses
    EOA,
    DAOSpace,
    VerifierSpace
  }

  mapping(address => ActorType) public ghost_actorType;

  // SpaceRegistry
  address[] public ghost_registeredAddresses;
  mapping(address => bool) public ghost_isAddressRegistered;
  mapping(address => bool) public ghost_addressEverRegistered;
  bytes16[] public ghost_registeredSpaceIds;
  mapping(bytes16 => bool) public ghost_isSpaceIdRegistered;
  mapping(address => address) public ghost_migrations;
  uint256 public ghost_acceptedMigrations;
  uint256 public ghost_totalRegistrations;
  uint256 public ghost_totalClears;

  // Factory
  uint256 public ghost_factoryCreatedSpaces;
  address[] public ghost_factoryCreatedSpaceAddresses;

  // DAOSpace
  uint256 public ghost_proposalCounter;
  mapping(address => bytes16[]) public ghost_activeProposals;
  mapping(bytes16 => mapping(address => bool)) public ghost_hasVoted;
  mapping(bytes16 => uint256) public ghost_yesVotes;
  mapping(bytes16 => uint256) public ghost_noVotes;
  mapping(bytes16 => uint256) public ghost_abstainVotes;
  mapping(bytes16 => bool) public ghost_proposalExecuted;
  mapping(address => uint256) public ghost_editorsAdded;
  mapping(address => uint256) public ghost_editorsRemoved;
  mapping(address => uint256) public ghost_membersAdded;
  mapping(address => uint256) public ghost_membersRemoved;
  mapping(address => address[]) public ghost_daoEditors;
  mapping(address => mapping(address => bool)) public ghost_isEditor;

  // VerifierSpace
  mapping(address => uint256) public ghost_lastNonceBefore;
  mapping(address => uint256) public ghost_lastNonceAfter;
  uint256 public ghost_successfulVerifyCalls;
  bool public ghost_replayAttackSucceeded;

  function ghost_registeredAddressesLength() external view returns (uint256) {
    return ghost_registeredAddresses.length;
  }

  function ghost_registeredSpaceIdsLength() external view returns (uint256) {
    return ghost_registeredSpaceIds.length;
  }

  function ghost_factoryCreatedSpaceAddressesLength() external view returns (uint256) {
    return ghost_factoryCreatedSpaceAddresses.length;
  }

  function ghost_activeProposalsLength(address _daoSpace) external view returns (uint256) {
    return ghost_activeProposals[_daoSpace].length;
  }

  function ghost_daoEditorsLength(address _daoSpace) external view returns (uint256) {
    return ghost_daoEditors[_daoSpace].length;
  }
}
