// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {Setup} from 'test/invariants/fuzz/Setup.t.sol';

/// @notice Invariant tests for SpaceRegistry, Factory, DAOSpace, and VerifierSpace
contract Invariants is Setup {
  bytes32 internal constant _BEACON_SLOT = bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1);

  /// @notice SR-INV-1: addressToSpaceId[spaceIdToAddress[spaceId]] == spaceId
  function invariant_SR_INV_1_bidirectional_spaceId_to_address() public view {
    uint256 _length = handlerSpaceRegistry.ghost_registeredSpaceIdsLength();

    for (uint256 _i = 0; _i < _length; _i++) {
      bytes16 _spaceId = handlerSpaceRegistry.ghost_registeredSpaceIds(_i);
      if (!handlerSpaceRegistry.ghost_isSpaceIdRegistered(_spaceId)) continue;

      address _spaceAddr = spaceRegistryProxy.spaceIdToAddress(_spaceId);
      bytes16 _reverseSpaceId = spaceRegistryProxy.addressToSpaceId(_spaceAddr);

      assertEq(_reverseSpaceId, _spaceId, 'SR-INV-1: addressToSpaceId[spaceIdToAddress[spaceId]] != spaceId');
    }
  }

  /// @notice SR-INV-2: spaceIdToAddress[addressToSpaceId[addr]] == addr
  function invariant_SR_INV_2_bidirectional_address_to_spaceId() public view {
    uint256 _length = handlerSpaceRegistry.ghost_registeredAddressesLength();

    for (uint256 _i = 0; _i < _length; _i++) {
      address _addr = handlerSpaceRegistry.ghost_registeredAddresses(_i);
      if (!handlerSpaceRegistry.ghost_isAddressRegistered(_addr)) continue;

      bytes16 _spaceId = spaceRegistryProxy.addressToSpaceId(_addr);
      address _reverseAddr = spaceRegistryProxy.spaceIdToAddress(_spaceId);

      assertEq(_reverseAddr, _addr, 'SR-INV-2: spaceIdToAddress[addressToSpaceId[addr]] != addr');
    }
  }

  /// @notice SR-INV-3: After migration, old address has no spaceId (unless re-registered)
  function invariant_SR_INV_3_migration_consistency() public view {
    uint256 _length = handlerSpaceRegistry.ghost_registeredAddressesLength();

    for (uint256 _i = 0; _i < _length; _i++) {
      address _oldAddr = handlerSpaceRegistry.ghost_registeredAddresses(_i);
      address _newAddr = handlerSpaceRegistry.ghost_migrations(_oldAddr);
      if (_newAddr == address(0)) continue;

      bytes16 _oldSpaceId = spaceRegistryProxy.addressToSpaceId(_oldAddr);
      bool _isRegistered = handlerSpaceRegistry.ghost_isAddressRegistered(_oldAddr);

      if (_isRegistered) {
        assertNotEq(_oldSpaceId, bytes16(0), 'SR-INV-3: Re-registered address has no spaceId');
      } else {
        assertEq(_oldSpaceId, bytes16(0), 'SR-INV-3: Old address still has spaceId after migration');
      }
    }
  }

  /// @notice SR-INV-4: activeSpaceIds(spaceId) == (registeredSpaceIds(spaceId) && !archivedSpaceIds(spaceId))
  function invariant_SR_INV_4_active_space_definition() public view {
    uint256 _length = handlerSpaceRegistry.ghost_registeredSpaceIdsLength();

    for (uint256 _i = 0; _i < _length; _i++) {
      bytes16 _spaceId = handlerSpaceRegistry.ghost_registeredSpaceIds(_i);
      bool _isRegistered = handlerSpaceRegistry.ghost_isSpaceIdRegistered(_spaceId);
      bool _isArchived = handlerSpaceRegistry.ghost_isSpaceIdArchived(_spaceId);
      bool _isActive = spaceRegistryProxy.activeSpaceIds(_spaceId);

      bool _expectedActive = _isRegistered && !_isArchived;
      assertEq(_isActive, _expectedActive, 'SR-INV-4: activeSpaceIds does not match definition');
    }
  }

  /// @notice FACT-INV-1: Every factory-created Space has a registered spaceId
  /// @dev DAOSpace could clear via governance proposal, but handlers don't create such proposals
  function invariant_FACT_INV_1_no_orphan_spaces() public view {
    uint256 _length = handlerSpaceRegistry.ghost_factoryCreatedSpaceAddressesLength();

    for (uint256 _i = 0; _i < _length; _i++) {
      address _spaceAddr = handlerSpaceRegistry.ghost_factoryCreatedSpaceAddresses(_i);
      bytes16 _spaceId = spaceRegistryProxy.addressToSpaceId(_spaceAddr);
      assertNotEq(_spaceId, bytes16(0), 'FACT-INV-1: Factory-created space has no spaceId');
    }
  }

  /// @notice FACT-INV-2: All Spaces from same factory share the same Beacon
  function invariant_FACT_INV_2_consistent_beacon() public view {
    address _expectedDAOBeacon = daoSpaceFactoryProxy.daoSpaceBeacon();
    address _expectedVerifierBeacon = verifierSpaceFactoryProxy.verifierSpaceBeacon();

    for (uint256 _i = 0; _i < daoSpaceActors.length; _i++) {
      address _actualBeacon = _getBeaconAddress(daoSpaceActors[_i]);
      assertEq(_actualBeacon, _expectedDAOBeacon, 'FACT-INV-2: DAOSpace beacon mismatch');
    }

    for (uint256 _i = 0; _i < verifierSpaceActors.length; _i++) {
      address _actualBeacon = _getBeaconAddress(verifierSpaceActors[_i]);
      assertEq(_actualBeacon, _expectedVerifierBeacon, 'FACT-INV-2: VerifierSpace beacon mismatch');
    }
  }

  function _getBeaconAddress(address proxy) internal view returns (address) {
    bytes32 _beaconValue = vm.load(proxy, _BEACON_SLOT);
    return address(uint160(uint256(_beaconValue)));
  }

  /// @notice DS-INV-1: Executed proposals must have reached support threshold
  function invariant_DS_INV_1_execution_requires_passed() public view {
    for (uint256 _i = 0; _i < daoSpaceActors.length; _i++) {
      DAOSpace _dao = DAOSpace(daoSpaceActors[_i]);
      uint256 _proposalCount = handlerDAOSpace.ghost_activeProposalsLength(daoSpaceActors[_i]);

      for (uint256 _j = 0; _j < _proposalCount; _j++) {
        bytes16 _proposalId = handlerDAOSpace.ghost_activeProposals(daoSpaceActors[_i], _j);
        (bool _executed,,,,) = _dao.getLatestProposalInformation(_proposalId);

        if (_executed) {
          assertTrue(
            _dao.isSupportThresholdReached(_proposalId), 'DS-INV-1: Executed proposal did not reach support threshold'
          );
          assertFalse(_dao.canExecuteProposal(_proposalId), 'DS-INV-1: Executed proposal still executable');
        }
      }
    }
  }

  /// @notice DS-INV-2: Executed flag cannot be unset
  function invariant_DS_INV_2_no_double_execution() public view {
    for (uint256 _i = 0; _i < daoSpaceActors.length; _i++) {
      DAOSpace _dao = DAOSpace(daoSpaceActors[_i]);
      uint256 _proposalCount = handlerDAOSpace.ghost_activeProposalsLength(daoSpaceActors[_i]);

      for (uint256 _j = 0; _j < _proposalCount; _j++) {
        bytes16 _proposalId = handlerDAOSpace.ghost_activeProposals(daoSpaceActors[_i], _j);
        (bool _executed,,,,) = _dao.getLatestProposalInformation(_proposalId);

        if (handlerDAOSpace.ghost_proposalExecuted(_proposalId)) {
          assertTrue(_executed, 'DS-INV-2: Executed flag was reset');
        }
      }
    }
  }

  /// @notice DS-INV-3: Total votes cannot exceed max editors ever added
  function invariant_DS_INV_3_single_vote_per_editor() public view {
    for (uint256 _i = 0; _i < daoSpaceActors.length; _i++) {
      DAOSpace _dao = DAOSpace(daoSpaceActors[_i]);
      uint256 _proposalCount = handlerDAOSpace.ghost_activeProposalsLength(daoSpaceActors[_i]);
      uint256 _maxEditorsEver = handlerDAOSpace.ghost_editorsAdded(daoSpaceActors[_i]);

      for (uint256 _j = 0; _j < _proposalCount; _j++) {
        bytes16 _proposalId = handlerDAOSpace.ghost_activeProposals(daoSpaceActors[_i], _j);
        (,,, IDAOSpace.Tally memory _tally,) = _dao.getLatestProposalInformation(_proposalId);
        uint256 _totalVotesCast = _tally.yes + _tally.no + _tally.abstain;
        assertLe(_totalVotesCast, _maxEditorsEver, 'DS-INV-3: Vote count exceeds max editors');
      }
    }
  }

  /// @notice DS-INV-4: totalEditors() must match editorsAdded - editorsRemoved
  function invariant_DS_INV_4_role_count_consistency() public view {
    for (uint256 _i = 0; _i < daoSpaceActors.length; _i++) {
      DAOSpace _dao = DAOSpace(daoSpaceActors[_i]);
      uint256 _added = handlerDAOSpace.ghost_editorsAdded(daoSpaceActors[_i]);
      uint256 _removed = handlerDAOSpace.ghost_editorsRemoved(daoSpaceActors[_i]);
      uint256 _expectedEditors = _added > _removed ? _added - _removed : 0;

      assertEq(_dao.totalEditors(), _expectedEditors, "DS-INV-4: totalEditors doesn't match added - removed count");
    }
  }

  /// @notice DS-INV-5: Contract tally must match ghost state
  function invariant_DS_INV_5_vote_tally_consistency() public view {
    for (uint256 _i = 0; _i < daoSpaceActors.length; _i++) {
      DAOSpace _dao = DAOSpace(daoSpaceActors[_i]);
      uint256 _proposalCount = handlerDAOSpace.ghost_activeProposalsLength(daoSpaceActors[_i]);

      for (uint256 _j = 0; _j < _proposalCount; _j++) {
        bytes16 _proposalId = handlerDAOSpace.ghost_activeProposals(daoSpaceActors[_i], _j);
        (,,, IDAOSpace.Tally memory _tally,) = _dao.getLatestProposalInformation(_proposalId);

        assertEq(_tally.yes, handlerDAOSpace.ghost_yesVotes(_proposalId), 'DS-INV-5: Yes mismatch');
        assertEq(_tally.no, handlerDAOSpace.ghost_noVotes(_proposalId), 'DS-INV-5: No mismatch');
        assertEq(_tally.abstain, handlerDAOSpace.ghost_abstainVotes(_proposalId), 'DS-INV-5: Abstain mismatch');
      }
    }
  }

  /// @notice DS-INV-6: Quorum setting must be <= total editors
  function invariant_DS_INV_6_quorum_valid() public view {
    for (uint256 _i = 0; _i < daoSpaceActors.length; _i++) {
      DAOSpace _dao = DAOSpace(daoSpaceActors[_i]);
      assertLe(_dao.votingSettings().quorum, _dao.totalEditors(), 'DS-INV-6: Quorum exceeds total editors');
    }
  }

  /// @notice DS-INV-7: Fast path threshold must be <= total editors
  function invariant_DS_INV_7_fastpath_threshold_valid() public view {
    for (uint256 _i = 0; _i < daoSpaceActors.length; _i++) {
      DAOSpace _dao = DAOSpace(daoSpaceActors[_i]);
      assertLe(
        _dao.votingSettings().flatSupportThreshold, _dao.totalEditors(), 'DS-INV-7: Fast path threshold exceeds editors'
      );
    }
  }

  /// @notice VS-INV-1: Nonce must monotonically increase
  function invariant_VS_INV_1_nonce_monotonic() public view {
    for (uint256 _i = 0; _i < verifierSpaceActors.length; _i++) {
      uint256 _currentNonce = VerifierSpace(verifierSpaceActors[_i]).replayNonce();
      uint256 _recordedAfter = handlerVerifierSpace.ghost_lastNonceAfter(verifierSpaceActors[_i]);
      assertGe(_currentNonce, _recordedAfter, 'VS-INV-1: Current nonce less than expected');
    }
  }

  /// @notice VS-INV-2: Replay attacks must fail
  function invariant_VS_INV_2_replay_protection() public view {
    assertFalse(handlerVerifierSpace.ghost_replayAttackSucceeded(), 'VS-INV-2: Replay attack succeeded');
  }
}
