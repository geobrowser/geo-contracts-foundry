// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {IntegrationBase} from 'test/integration/L3/IntegrationBase.t.sol';

import {DAOSpace} from 'contracts/L3/DAOSpace.sol';
import {VerifierSpace} from 'contracts/L3/VerifierSpace.sol';
import {MockDAOSpaceV2} from 'test/integration/L3/mocks/MockDAOSpaceV2.sol';
import {MockVerifierSpaceV2} from 'test/integration/L3/mocks/MockVerifierSpaceV2.sol';

import 'script/Constants.sol' as Constants;

contract IntegrationUpgradeBeaconImplementation is IntegrationBase {
  bytes32 internal constant _EIP712_DOMAIN_TYPEHASH =
    keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)');

  // Spaces
  MockDAOSpaceV2 public daoSpaceImplementationBis;
  MockDAOSpaceV2 public daoSpaceProxyA;
  MockDAOSpaceV2 public daoSpaceProxyB;

  VerifierSpace public verifierSpaceImplementationBis;
  VerifierSpace public verifierSpaceProxyA;
  VerifierSpace public verifierSpaceProxyB;

  // Space IDs
  bytes16 internal _daoSpaceProxyAId;
  bytes16 internal _daoSpaceProxyBId;
  bytes16 internal _verifierSpaceProxyAId;
  bytes16 internal _verifierSpaceProxyBId;

  function setUp() public override {
    IntegrationBase.setUp();
    vm.selectFork(_geoForkId);

    verifierSpaceProxyA = verifierSpaceProxy;
    verifierSpaceProxyB = VerifierSpace(verifierSpaceFactoryProxy.createVerifierSpaceProxy(eoaSpace));
    _verifierSpaceProxyAId = _verifierSpaceProxyId;
    _verifierSpaceProxyBId = spaceRegistryProxy.addressToSpaceId(address(verifierSpaceProxyB));

    daoSpaceProxyA = MockDAOSpaceV2(address(daoSpaceProxy));
    daoSpaceProxyB = MockDAOSpaceV2(
      daoSpaceFactoryProxy.createDAOSpaceProxy(
        _votingSettings,
        _initialSpaceEditors,
        _initialSpaceMembers,
        _initialEditsContentUri,
        _initialEditsMetadata,
        _initialTopicId
      )
    );
    _daoSpaceProxyAId = _daoSpaceProxyId;
    _daoSpaceProxyBId = spaceRegistryProxy.addressToSpaceId(address(daoSpaceProxyB));

    verifierSpaceImplementationBis = new MockVerifierSpaceV2();
    daoSpaceImplementationBis = new MockDAOSpaceV2();
  }

  function test_UpgradeBeaconImplementation_DAOSpace() external {
    assertEq(daoSpaceBeacon.implementation(), address(daoSpaceImplementation));
    assertEq(daoSpaceImplementation.version(), '1.0.0');
    assertEq(daoSpaceProxyA.version(), '1.0.0');
    assertEq(daoSpaceProxyB.version(), '1.0.0');
    // _initialMembers
    assertTrue(daoSpaceProxyA.hasRole(daoSpaceImplementation.MEMBER(), _eoaSpaceId));
    assertTrue(daoSpaceProxyB.hasRole(daoSpaceImplementation.MEMBER(), _eoaSpaceId));
    // actionIsFastPathValid
    assertTrue(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.addMember.selector));
    assertTrue(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.addMember.selector));
    assertTrue(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.removeMember.selector));
    assertTrue(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.removeMember.selector));
    assertFalse(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.addEditor.selector));
    assertFalse(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.addEditor.selector));
    assertFalse(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.removeEditor.selector));
    assertFalse(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.removeEditor.selector));

    vm.prank(Constants.GEO_GEO_MULTISIG_COUNCIL);
    daoSpaceBeacon.upgradeTo(address(daoSpaceImplementationBis));

    uint256 _initialTotalMembers = _initialSpaceMembers.length;
    daoSpaceProxyA.initialize(abi.encode(_initialTotalMembers));
    daoSpaceProxyB.initialize(abi.encode(_initialTotalMembers));

    vm.prank(address(daoSpaceProxyA));
    daoSpaceProxyA.addMember(_daoSpaceProxyAId);
    vm.prank(address(daoSpaceProxyB));
    daoSpaceProxyB.addMember(_daoSpaceProxyBId);

    assertEq(daoSpaceBeacon.implementation(), address(daoSpaceImplementationBis));
    assertEq(daoSpaceImplementationBis.version(), '2.0.0');
    assertEq(daoSpaceProxyA.version(), '2.0.0');
    assertEq(daoSpaceProxyB.version(), '2.0.0');
    // totalMembers
    assertEq(daoSpaceProxyA.totalMembers(), _initialTotalMembers + 1);
    assertEq(daoSpaceProxyB.totalMembers(), _initialTotalMembers + 1);
    // actionIsFastPathValid
    assertFalse(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.addMember.selector));
    assertFalse(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.addMember.selector));
    assertFalse(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.removeMember.selector));
    assertFalse(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.removeMember.selector));
    assertTrue(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.addEditor.selector));
    assertTrue(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.addEditor.selector));
    assertTrue(daoSpaceProxyA.actionIsFastPathValid(DAOSpace.removeEditor.selector));
    assertTrue(daoSpaceProxyB.actionIsFastPathValid(DAOSpace.removeEditor.selector));
  }

  function test_UpgradeBeaconImplementation_VerifierSpace() external {
    assertEq(verifierSpaceBeacon.implementation(), address(verifierSpaceImplementation));
    assertEq(verifierSpaceImplementation.version(), '1.0.0');
    assertEq(verifierSpaceProxyA.version(), '1.0.0');
    assertEq(verifierSpaceProxyB.version(), '1.0.0');

    // Domain separator used in `verify` must match the domain implied by current `name()` / `version()` (not init-time storage alone).
    assertEq(
      verifierSpaceProxyA.domainSeparatorV4(),
      _expectedVerifierSpaceDomainSeparator(verifierSpaceProxyA, verifierSpaceProxyA.version())
    );
    assertEq(
      verifierSpaceProxyB.domainSeparatorV4(),
      _expectedVerifierSpaceDomainSeparator(verifierSpaceProxyB, verifierSpaceProxyB.version())
    );

    vm.prank(Constants.GEO_GEO_MULTISIG_COUNCIL);
    verifierSpaceBeacon.upgradeTo(address(verifierSpaceImplementationBis));

    assertEq(verifierSpaceBeacon.implementation(), address(verifierSpaceImplementationBis));
    assertEq(verifierSpaceImplementationBis.version(), '2.0.0');
    assertEq(verifierSpaceProxyA.version(), '2.0.0');
    assertEq(verifierSpaceProxyB.version(), '2.0.0');

    assertEq(
      verifierSpaceProxyA.domainSeparatorV4(),
      _expectedVerifierSpaceDomainSeparator(verifierSpaceProxyA, verifierSpaceProxyA.version())
    );
    assertEq(
      verifierSpaceProxyB.domainSeparatorV4(),
      _expectedVerifierSpaceDomainSeparator(verifierSpaceProxyB, verifierSpaceProxyB.version())
    );
  }

  /// @notice Replicates OZ `_buildDomainSeparator` for the given semver strings (same inputs `verify` uses via overrides).
  function _expectedVerifierSpaceDomainSeparator(
    VerifierSpace _proxy,
    string memory _version
  ) internal view returns (bytes32) {
    return keccak256(
      abi.encode(
        _EIP712_DOMAIN_TYPEHASH,
        keccak256(bytes(_proxy.name())),
        keccak256(bytes(_version)),
        block.chainid,
        address(_proxy)
      )
    );
  }
}
