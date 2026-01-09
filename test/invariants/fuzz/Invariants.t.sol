// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Setup} from './Setup.t.sol';
import {DAOSpace} from 'contracts/DAOSpace.sol';
import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {IDAOSpace} from 'interfaces/IDAOSpace.sol';

/// @notice Invariant tests for SpaceRegistry, Factory, DAOSpace, and VerifierSpace
contract Invariants is Setup {
  /// @notice SR-INV-1: addressToSpaceId[spaceIdToAddress[spaceId]] == spaceId
  function invariant_SR_INV_1_bidirectional_spaceId_to_address() public view {
    uint256 length = handlerSpaceRegistry.ghost_registeredSpaceIdsLength();

    for (uint256 i = 0; i < length; i++) {
      bytes16 spaceId = handlerSpaceRegistry.ghost_registeredSpaceIds(i);

      // Only check currently registered spaceIds
      if (!handlerSpaceRegistry.ghost_isSpaceIdRegistered(spaceId)) continue;

      // Get the address for this spaceId
      address spaceAddr = spaceRegistryProxy.spaceIdToAddress(spaceId);

      // The reverse lookup should return the same spaceId
      bytes16 reverseSpaceId = spaceRegistryProxy.addressToSpaceId(spaceAddr);

      assertEq(reverseSpaceId, spaceId, 'SR-INV-1: addressToSpaceId[spaceIdToAddress[spaceId]] != spaceId');
    }
  }

  /// @notice SR-INV-2: spaceIdToAddress[addressToSpaceId[addr]] == addr
  function invariant_SR_INV_2_bidirectional_address_to_spaceId() public view {
    uint256 length = handlerSpaceRegistry.ghost_registeredAddressesLength();

    for (uint256 i = 0; i < length; i++) {
      address addr = handlerSpaceRegistry.ghost_registeredAddresses(i);

      // Only check currently registered addresses
      if (!handlerSpaceRegistry.ghost_isAddressRegistered(addr)) continue;

      // Get the spaceId for this address
      bytes16 spaceId = spaceRegistryProxy.addressToSpaceId(addr);

      // The reverse lookup should return the same address
      address reverseAddr = spaceRegistryProxy.spaceIdToAddress(spaceId);

      assertEq(reverseAddr, addr, 'SR-INV-2: spaceIdToAddress[addressToSpaceId[addr]] != addr');
    }
  }

  /// @notice SR-INV-4: After migration, old address has no spaceId (unless re-registered)
  function invariant_SR_INV_4_migration_consistency() public view {
    uint256 length = handlerSpaceRegistry.ghost_registeredAddressesLength();

    for (uint256 i = 0; i < length; i++) {
      address oldAddr = handlerSpaceRegistry.ghost_registeredAddresses(i);
      address newAddr = handlerSpaceRegistry.ghost_migrations(oldAddr);

      // Skip if no migration from this address
      if (newAddr == address(0)) continue;

      bytes16 oldSpaceId = spaceRegistryProxy.addressToSpaceId(oldAddr);

      if (!handlerSpaceRegistry.ghost_isAddressRegistered(oldAddr)) {
        assertEq(oldSpaceId, bytes16(0), 'SR-INV-4: Old address still has spaceId after migration (no re-registration)');
      } else {
        assertNotEq(oldSpaceId, bytes16(0), 'SR-INV-4: Re-registered address has no spaceId');
      }
    }
  }

  /// @notice FACT-INV-1: Every factory-created Space has a registered spaceId
  /// @dev DAOSpace could clear via governance proposal, but handlers don't create such proposals
  function invariant_FACT_INV_1_no_orphan_spaces() public view {
    uint256 length = handlerSpaceRegistry.ghost_factoryCreatedSpaceAddressesLength();

    for (uint256 i = 0; i < length; i++) {
      address spaceAddr = handlerSpaceRegistry.ghost_factoryCreatedSpaceAddresses(i);
      bytes16 spaceId = spaceRegistryProxy.addressToSpaceId(spaceAddr);
      assertNotEq(spaceId, bytes16(0), 'FACT-INV-1: Factory-created space has no spaceId');
    }
  }

  /// @notice FACT-INV-2: All Spaces from same factory share the same Beacon
  function invariant_FACT_INV_2_consistent_beacon() public view {
    address expectedDAOBeacon = daoSpaceFactoryProxy.daoSpaceBeacon();
    address expectedVerifierBeacon = verifierSpaceFactoryProxy.verifierSpaceBeacon();

    for (uint256 i = 0; i < daoSpaceActors.length; i++) {
      bytes32 beaconSlot = bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1);
      bytes32 beaconValue = vm.load(daoSpaceActors[i], beaconSlot);
      address actualBeacon = address(uint160(uint256(beaconValue)));

      assertEq(actualBeacon, expectedDAOBeacon, 'FACT-INV-2: DAOSpace beacon mismatch');
    }

    for (uint256 i = 0; i < verifierSpaceActors.length; i++) {
      bytes32 beaconSlot = bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1);
      bytes32 beaconValue = vm.load(verifierSpaceActors[i], beaconSlot);
      address actualBeacon = address(uint160(uint256(beaconValue)));

      assertEq(actualBeacon, expectedVerifierBeacon, 'FACT-INV-2: VerifierSpace beacon mismatch');
    }
  }

  /// @notice DS-INV-1: Executed proposals must have reached support threshold
  function invariant_DS_INV_1_execution_requires_passed() public view {
    for (uint256 i = 0; i < daoSpaceActors.length; i++) {
      address daoSpace = daoSpaceActors[i];
      DAOSpace dao = DAOSpace(daoSpace);
      uint256 proposalCount = handlerDAOSpace.getActiveProposalsCount(daoSpace);

      for (uint256 j = 0; j < proposalCount; j++) {
        bytes16 proposalId = handlerDAOSpace.getActiveProposal(daoSpace, j);

        (bool executed,,,,) = dao.getLatestProposalInformation(proposalId);
        if (executed) {
          assertTrue(
            dao.isSupportThresholdReached(proposalId), 'DS-INV-1: Executed proposal did not reach support threshold'
          );
        }
      }
    }
  }

  /// @notice DS-INV-2: Executed flag cannot be unset
  function invariant_DS_INV_2_no_double_execution() public view {
    for (uint256 i = 0; i < daoSpaceActors.length; i++) {
      address daoSpace = daoSpaceActors[i];
      uint256 proposalCount = handlerDAOSpace.getActiveProposalsCount(daoSpace);

      for (uint256 j = 0; j < proposalCount; j++) {
        bytes16 proposalId = handlerDAOSpace.getActiveProposal(daoSpace, j);
        (bool executed,,,,) = DAOSpace(daoSpace).getLatestProposalInformation(proposalId);
        if (handlerDAOSpace.ghost_proposalExecuted(proposalId)) {
          assertTrue(executed, 'DS-INV-2: Executed flag was reset');
        }
      }
    }
  }

  /// @notice DS-INV-5: Contract tally must match ghost state
  function invariant_DS_INV_5_vote_tally_consistency() public view {
    for (uint256 i = 0; i < daoSpaceActors.length; i++) {
      address daoSpace = daoSpaceActors[i];
      uint256 proposalCount = handlerDAOSpace.getActiveProposalsCount(daoSpace);

      for (uint256 j = 0; j < proposalCount; j++) {
        bytes16 proposalId = handlerDAOSpace.getActiveProposal(daoSpace, j);
        (,,, IDAOSpace.Tally memory tally,) = DAOSpace(daoSpace).getLatestProposalInformation(proposalId);

        assertEq(tally.yes, handlerDAOSpace.ghost_yesVotes(proposalId), 'DS-INV-5: Yes mismatch');
        assertEq(tally.no, handlerDAOSpace.ghost_noVotes(proposalId), 'DS-INV-5: No mismatch');
        assertEq(tally.abstain, handlerDAOSpace.ghost_abstainVotes(proposalId), 'DS-INV-5: Abstain mismatch');
      }
    }
  }

  /// @notice SR-INV-8: Quorum setting must be <= total editors
  function invariant_SR_INV_8_quorum_valid() public view {
    for (uint256 i = 0; i < daoSpaceActors.length; i++) {
      DAOSpace dao = DAOSpace(daoSpaceActors[i]);
      IDAOSpace.VotingSettings memory settings = dao.votingSettings();
      uint256 totalEditors = dao.totalEditors();

      assertLe(settings.quorum, totalEditors, 'SR-INV-8: Quorum exceeds total editors');
    }
  }

  /// @notice SR-INV-9: Fast path threshold must be <= total editors
  function invariant_SR_INV_9_fastpath_threshold_valid() public view {
    for (uint256 i = 0; i < daoSpaceActors.length; i++) {
      DAOSpace dao = DAOSpace(daoSpaceActors[i]);
      IDAOSpace.VotingSettings memory settings = dao.votingSettings();
      uint256 totalEditors = dao.totalEditors();

      assertLe(settings.fastPathFlatThreshold, totalEditors, 'SR-INV-9: Fast path threshold exceeds total editors');
    }
  }

  /// @notice VS-INV-1: Nonce must monotonically increase
  function invariant_VS_INV_1_nonce_monotonic() public view {
    for (uint256 i = 0; i < verifierSpaceActors.length; i++) {
      address verifierSpace = verifierSpaceActors[i];
      VerifierSpace vs = VerifierSpace(verifierSpace);
      uint256 currentNonce = vs.replayNonce();
      uint256 recordedAfter = handlerVerifierSpace.ghost_lastNonceAfter(verifierSpace);
      assertGe(currentNonce, recordedAfter, 'VS-INV-1: Current nonce less than expected');
    }
  }

  /// @notice VS-INV-2: Replay attacks must fail
  function invariant_VS_INV_2_replay_protection() public view {
    assertFalse(handlerVerifierSpace.ghost_replayAttackSucceeded(), 'VS-INV-2: Replay attack succeeded');
  }

  /// @notice DS-INV-3: Total votes cannot exceed max editors ever added
  function invariant_DS_INV_3_single_vote_per_editor() public view {
    for (uint256 i = 0; i < daoSpaceActors.length; i++) {
      address daoSpace = daoSpaceActors[i];
      DAOSpace dao = DAOSpace(daoSpace);
      uint256 proposalCount = handlerDAOSpace.getActiveProposalsCount(daoSpace);
      uint256 maxEditorsEver = handlerDAOSpace.ghost_editorsAdded(daoSpace);

      for (uint256 j = 0; j < proposalCount; j++) {
        bytes16 proposalId = handlerDAOSpace.getActiveProposal(daoSpace, j);
        (,,, IDAOSpace.Tally memory tally,) = dao.getLatestProposalInformation(proposalId);
        uint256 totalVotesCast = tally.yes + tally.no + tally.abstain;
        assertLe(totalVotesCast, maxEditorsEver, 'DS-INV-3: Vote count exceeds max editors');
      }
    }
  }

  /// @notice DS-INV-4: totalEditors() must match editorsAdded - editorsRemoved
  function invariant_DS_INV_4_role_count_consistency() public view {
    for (uint256 i = 0; i < daoSpaceActors.length; i++) {
      address daoSpace = daoSpaceActors[i];
      DAOSpace dao = DAOSpace(daoSpace);

      uint256 reportedEditors = dao.totalEditors();
      uint256 added = handlerDAOSpace.ghost_editorsAdded(daoSpace);
      uint256 removed = handlerDAOSpace.ghost_editorsRemoved(daoSpace);
      uint256 expectedEditors = added > removed ? added - removed : 0;
      assertEq(reportedEditors, expectedEditors, "DS-INV-4: totalEditors doesn't match added - removed count");
    }
  }
}
