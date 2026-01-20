// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {DeployGEOBrowser} from 'script/DeployGEOBrowser.s.sol';

abstract contract IntegrationBase is TestHelper, DeployGEOBrowser {
  uint256 internal constant _ARBITRUM_TESTNET_FORK_BLOCK = 200_000_000;
  uint256 internal constant _GEO_TESTNET_FORK_BLOCK = 500;

  uint256 internal _arbitrumTestnetForkId;
  uint256 internal _geoTestnetForkId;

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

  function setUp() public virtual override {
    _arbitrumTestnetForkId = vm.createFork(vm.rpcUrl('arbitrum_testnet'), _ARBITRUM_TESTNET_FORK_BLOCK);
    _geoTestnetForkId = vm.createFork(vm.rpcUrl('geo_testnet'), _GEO_TESTNET_FORK_BLOCK);

    (eoaSpace, _eoaSpacePrivateKey) = makeAddrAndKey('eoaSpace');

    vm.selectFork(_arbitrumTestnetForkId);
    // Deploy GEO incentives contracts
    _deployGEOIncentives();

    vm.selectFork(_geoTestnetForkId);
    // Deploy GEO browser contracts
    _deployGEOBrowser();
    // Register EOA, DAO, and verifier spaces
    _registerSpaces();
  }

  function _deployGEOIncentives() internal {}

  function _deployGEOBrowser() internal {
    // Set up and run deployment script
    DeployGEOBrowser.setUp();
    DeployGEOBrowser.run();
  }

  function _registerSpaces() internal {
    // Register EOA space
    vm.prank(eoaSpace);
    spaceRegistryProxy.registerSpaceId(keccak256('EOA_SPACE'), '1.0.0');
    _eoaSpaceId = spaceRegistryProxy.addressToSpaceId(eoaSpace);

    // Deploy and register DAO space
    _votingSettings.duration = daoSpaceImplementation.MINIMUM_VOTING_DURATION();
    _initialSpaceEditors = new bytes16[](1);
    _initialSpaceEditors[0] = _eoaSpaceId;
    _initialSpaceMembers = new bytes16[](1);
    _initialSpaceMembers[0] = _eoaSpaceId;

    daoSpaceProxy = DAOSpace(
      daoSpaceFactoryProxy.createDAOSpaceProxy(
        _votingSettings, _initialSpaceEditors, _initialSpaceMembers, _initialEditsContentUri, _initialEditsMetadata
      )
    );
    _daoSpaceProxyId = spaceRegistryProxy.addressToSpaceId(address(daoSpaceProxy));

    // Deploy and register verifier space
    verifierSpaceProxy = VerifierSpace(verifierSpaceFactoryProxy.createVerifierSpaceProxy(eoaSpace));
    _verifierSpaceProxyId = spaceRegistryProxy.addressToSpaceId(address(verifierSpaceProxy));
  }
}
