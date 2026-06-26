// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {IntegrationBase} from 'test/integration/L3/IntegrationBase.t.sol';

import {IVerifierSpace} from 'interfaces/L3/IVerifierSpace.sol';

import 'contracts/L3/ActionsConstants.sol' as ActionsConstants;

contract IntegrationSpaceVerification is IntegrationBase {
  bytes internal _comment = '_comment';

  function setUp() public override {
    IntegrationBase.setUp();
    vm.selectFork(_geoForkId);
  }

  function test_SpaceVerification() external {
    // Invalid writer: eoaSpace
    _setValidWriter(_eoaSpaceId, false);
    assertFalse(verifierSpaceProxy.validWriters(_eoaSpaceId));

    // COMMENTED (permissionless action)
    _commentTopic({_fromSpaceId: _eoaSpaceId, _toSpaceId: _verifierSpaceProxyId});

    vm.expectRevert(IVerifierSpace.InvalidWriter.selector);
    // TOPIC_UNSET (permissioned action)
    _unsetTopic({_fromSpaceId: _eoaSpaceId, _toSpaceId: _verifierSpaceProxyId, _signature: ''});

    // Valid writer: verifierSpaceProxy
    assertTrue(verifierSpaceProxy.validWriters(_verifierSpaceProxyId));

    vm.expectRevert(IVerifierSpace.InvalidSignature.selector);
    // TOPIC_UNSET (permissioned action)
    _unsetTopic({_fromSpaceId: _verifierSpaceProxyId, _toSpaceId: _verifierSpaceProxyId, _signature: ''});

    // Sign: TOPIC_UNSET (permissioned action)
    uint256 _replayNonce = verifierSpaceProxy.replayNonce();
    bytes memory _signature = _signUnsetTopicMessage({_toSpaceId: _verifierSpaceProxyId, _replayNonce: _replayNonce});

    // TOPIC_UNSET (permissioned action)
    _unsetTopic({_fromSpaceId: _verifierSpaceProxyId, _toSpaceId: _verifierSpaceProxyId, _signature: _signature});

    assertEq(verifierSpaceProxy.replayNonce(), _replayNonce + 1);

    vm.expectRevert(IVerifierSpace.InvalidSignature.selector);
    // TOPIC_UNSET (permissioned action)
    _unsetTopic({_fromSpaceId: _verifierSpaceProxyId, _toSpaceId: _verifierSpaceProxyId, _signature: _signature});
  }

  function _unsetTopic(bytes16 _fromSpaceId, bytes16 _toSpaceId, bytes memory _signature) internal {
    vm.prank(eoaSpace);
    // TOPIC_UNSET
    spaceRegistryProxy.enter(_fromSpaceId, _toSpaceId, ActionsConstants.TOPIC_UNSET, _initialTopicId, '', _signature);
  }

  function _commentTopic(bytes16 _fromSpaceId, bytes16 _toSpaceId) internal {
    vm.prank(eoaSpace);
    // COMMENTED
    spaceRegistryProxy.enter(_fromSpaceId, _toSpaceId, ActionsConstants.COMMENTED, _initialTopicId, _comment, '');
  }

  function _signUnsetTopicMessage(
    bytes16 _toSpaceId,
    uint256 _replayNonce
  ) internal view returns (bytes memory _signature) {
    // struct hash
    bytes32 _structHash = keccak256(
      abi.encode(
        verifierSpaceImplementation.MESSAGE_TYPEHASH(),
        _toSpaceId,
        ActionsConstants.TOPIC_UNSET,
        _initialTopicId,
        _replayNonce,
        keccak256('')
      )
    );
    // domain separator
    bytes32 _domainSeparator = keccak256(
      abi.encode(
        keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
        keccak256('VERIFIER_SPACE'),
        keccak256(bytes(verifierSpaceProxy.version())),
        block.chainid,
        address(verifierSpaceProxy)
      )
    );
    // digest
    bytes32 _digest = keccak256(abi.encodePacked('\x19\x01', _domainSeparator, _structHash));
    // signature
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_eoaSpacePrivateKey, _digest);
    _signature = abi.encodePacked(_r, _s, _v);
  }

  function _setValidWriter(bytes16 _spaceId, bool _valid) internal {
    vm.prank(eoaSpace);
    verifierSpaceProxy.setValidWriters(_spaceId, _valid);
  }
}
