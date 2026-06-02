// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {DeployGEOBrowser} from 'script/DeployGEOBrowser.s.sol';

abstract contract IntegrationBase is TestHelper, DeployGEOBrowser {
  uint256 internal constant _GEO_FORK_BLOCK = 500;

  uint256 internal _geoForkId;

  // Spaces
  address public eoaSpace;
  DAOSpace public daoSpaceProxy;
  VerifierSpace public verifierSpaceProxy;

  // Space private keys
  uint256 internal _eoaSpacePrivateKey;

  // Space IDs
  bytes16 internal _eoaSpaceId;
  bytes16 internal _daoSpaceProxyId;
  bytes16 internal _verifierSpaceProxyId;

  // Space settings
  IDAOSpace.VotingSettings internal _votingSettings;
  bytes16[] internal _initialSpaceEditors;
  bytes16[] internal _initialSpaceMembers;
  bytes internal _initialEditsContentUri;
  bytes internal _initialEditsMetadata;
  bytes16 internal _initialTopicId;

  function setUp() public virtual {
    _geoForkId = vm.createFork(vm.rpcUrl('geo'), _GEO_FORK_BLOCK);

    (eoaSpace, _eoaSpacePrivateKey) = makeAddrAndKey('eoaSpace');

    vm.selectFork(_geoForkId);
    // Deploy GEO browser contracts
    _deployGEOBrowser();
    // Register EOA, DAO, and verifier spaces
    _registerSpaces();
  }

  function _deployGEOBrowser() internal {
    // Run deployment script
    DeployGEOBrowser.run();
  }

  function _registerSpaces() internal {
    // Register EOA space
    vm.prank(eoaSpace);
    spaceRegistryProxy.registerSpaceId(keccak256('EOA_SPACE'), '1.0.0');
    _eoaSpaceId = spaceRegistryProxy.addressToSpaceId(eoaSpace);

    // Deploy and register verifier space
    verifierSpaceProxy = VerifierSpace(verifierSpaceFactoryProxy.createVerifierSpaceProxy(eoaSpace));
    _verifierSpaceProxyId = spaceRegistryProxy.addressToSpaceId(address(verifierSpaceProxy));

    // Deploy and register DAO space
    _votingSettings.partialPercentageSupportThreshold = 1e6; // 10%
    _votingSettings.universalPercentageSupportThreshold = 10e6; // 100%
    _votingSettings.flatSupportThreshold = 0;
    _votingSettings.quorum = 0;
    _votingSettings.duration = daoSpaceImplementation.MINIMUM_VOTING_DURATION();
    _votingSettings.disableFastPathAccessForNewMembers = true;
    _votingSettings.executionGracePeriod = daoSpaceImplementation.MINIMUM_EXECUTION_GRACE_PERIOD();
    _initialSpaceEditors = new bytes16[](2);
    _initialSpaceEditors[0] = _eoaSpaceId;
    _initialSpaceEditors[1] = _verifierSpaceProxyId;
    _initialSpaceMembers = new bytes16[](2);
    _initialSpaceMembers[0] = _eoaSpaceId;
    _initialSpaceMembers[1] = _verifierSpaceProxyId;
    _initialTopicId = '_initialTopicId';

    daoSpaceProxy = DAOSpace(
      daoSpaceFactoryProxy.createDAOSpaceProxy(
        _votingSettings,
        _initialSpaceEditors,
        _initialSpaceMembers,
        _initialEditsContentUri,
        _initialEditsMetadata,
        _initialTopicId
      )
    );
    _daoSpaceProxyId = spaceRegistryProxy.addressToSpaceId(address(daoSpaceProxy));
  }
}
