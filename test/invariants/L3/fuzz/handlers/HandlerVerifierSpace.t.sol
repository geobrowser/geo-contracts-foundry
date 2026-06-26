// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import 'contracts/L3/ActionsConstants.sol' as ActionsConstants;
import {SpaceRegistry} from 'contracts/L3/SpaceRegistry.sol';
import {VerifierSpace} from 'contracts/L3/VerifierSpace.sol';

import {L3BaseHandler} from 'test/invariants/L3/fuzz/handlers/L3BaseHandler.t.sol';

/// @notice Handler for VerifierSpace operations
contract HandlerVerifierSpace is L3BaseHandler {
  bytes32 internal constant _MESSAGE_TYPEHASH =
    keccak256('Message(bytes16 toSpaceId,bytes32 action,bytes32 subject,uint256 nonce,bytes data)');
  bytes32 internal constant _DOMAIN_TYPEHASH =
    keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)');

  bool public lastTxSucceeded;
  mapping(address => uint256) public verifierSpaceOwnerKeys;

  constructor(
    SpaceRegistry _spaceRegistry,
    address[] memory _eoaActors,
    address[] memory _daoSpaceActors,
    address[] memory _verifierSpaceActors,
    uint256[] memory _verifierSpaceOwnerKeys
  ) L3BaseHandler(_spaceRegistry, _eoaActors, _daoSpaceActors, _verifierSpaceActors) {
    for (uint256 _i = 0; _i < _verifierSpaceActors.length; _i++) {
      verifierSpaceOwnerKeys[_verifierSpaceActors[_i]] = _verifierSpaceOwnerKeys[_i];
    }
  }

  function handler_verifierSpace_enter(uint256 _verifierSpaceSeed, uint256 _toSpaceSeed) external {
    if (verifierSpaceActors.length == 0) {
      lastTxSucceeded = false;
      return;
    }

    address _verifierSpace = verifierSpaceActors[bound(_verifierSpaceSeed, 0, verifierSpaceActors.length - 1)];
    address _toSpace = _selectTargetSpace(_toSpaceSeed);
    if (_toSpace == address(0)) {
      lastTxSucceeded = false;
      return;
    }

    uint256 _ownerKey = verifierSpaceOwnerKeys[_verifierSpace];
    if (_ownerKey == 0) {
      lastTxSucceeded = false;
      return;
    }

    VerifierSpace _vs = VerifierSpace(_verifierSpace);
    uint256 _nonceBefore = _vs.replayNonce();
    ghost_lastNonceBefore[_verifierSpace] = _nonceBefore;

    bytes16 _verifierSpaceId = spaceRegistry.addressToSpaceId(_verifierSpace);
    bytes16 _toSpaceId = spaceRegistry.addressToSpaceId(_toSpace);

    bytes memory _data = abi.encode('test');
    bytes memory _signature = _signMessage(
      _verifierSpace, _ownerKey, _toSpaceId, ActionsConstants.UPVOTED, bytes32(uint256(1)), _nonceBefore, _data
    );

    vm.prank(msg.sender);
    try spaceRegistry.enter(
      _verifierSpaceId, _toSpaceId, ActionsConstants.UPVOTED, bytes32(uint256(1)), _data, _signature
    ) {
      ghost_lastNonceAfter[_verifierSpace] = _vs.replayNonce();
      ghost_successfulVerifyCalls++;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_verifierSpace_replayAttack(uint256 _verifierSpaceSeed) external {
    if (verifierSpaceActors.length == 0) {
      lastTxSucceeded = false;
      return;
    }

    address _verifierSpace = verifierSpaceActors[bound(_verifierSpaceSeed, 0, verifierSpaceActors.length - 1)];
    uint256 _ownerKey = verifierSpaceOwnerKeys[_verifierSpace];
    if (_ownerKey == 0) {
      lastTxSucceeded = false;
      return;
    }

    uint256 _currentNonce = VerifierSpace(_verifierSpace).replayNonce();
    if (_currentNonce == 0) {
      lastTxSucceeded = false;
      return;
    }

    bytes16 _verifierSpaceId = spaceRegistry.addressToSpaceId(_verifierSpace);

    uint256 _oldNonce = _currentNonce - 1;
    bytes memory _data = abi.encode('replay');
    bytes memory _signature = _signMessage(
      _verifierSpace, _ownerKey, _verifierSpaceId, ActionsConstants.UPVOTED, bytes32(uint256(1)), _oldNonce, _data
    );

    vm.prank(msg.sender);
    try spaceRegistry.enter(
      _verifierSpaceId, _verifierSpaceId, ActionsConstants.UPVOTED, bytes32(uint256(1)), _data, _signature
    ) {
      ghost_replayAttackSucceeded = true;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function _selectTargetSpace(uint256 _seed) internal view returns (address _targetSpace) {
    uint256 _totalSpaces = daoSpaceActors.length + verifierSpaceActors.length;
    if (_totalSpaces == 0) return address(0);

    uint256 _idx = bound(_seed, 0, _totalSpaces - 1);
    if (_idx < daoSpaceActors.length) {
      return daoSpaceActors[_idx];
    }
    return verifierSpaceActors[_idx - daoSpaceActors.length];
  }

  function _signMessage(
    address _verifierSpace,
    uint256 _ownerKey,
    bytes16 _toSpaceId,
    bytes32 _action,
    bytes32 _subject,
    uint256 _nonce,
    bytes memory _data
  ) internal view returns (bytes memory _signature) {
    bytes32 _domainSeparator = _computeDomainSeparator(_verifierSpace);
    bytes32 _structHash =
      keccak256(abi.encode(_MESSAGE_TYPEHASH, _toSpaceId, _action, _subject, _nonce, keccak256(_data)));
    bytes32 _digest = keccak256(abi.encodePacked('\x19\x01', _domainSeparator, _structHash));
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_ownerKey, _digest);
    return abi.encodePacked(_r, _s, _v);
  }

  function _computeDomainSeparator(address _verifierSpace) internal view returns (bytes32 _domainSeparator) {
    VerifierSpace _vs = VerifierSpace(_verifierSpace);
    return keccak256(
      abi.encode(
        _DOMAIN_TYPEHASH, keccak256(bytes(_vs.name())), keccak256(bytes(_vs.version())), block.chainid, _verifierSpace
      )
    );
  }
}
