// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {SpaceRegistry} from 'contracts/SpaceRegistry.sol';
import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import 'src/ActionsConstants.sol' as ActionsConstants;

import {BaseHandler} from 'test/invariants/fuzz/handlers/BaseHandler.t.sol';

/// @notice Handler for VerifierSpace operations
contract HandlerVerifierSpace is BaseHandler {
  bytes32 internal constant MESSAGE_TYPEHASH =
    keccak256('Message(bytes16 toSpaceId,bytes32 action,bytes32 subject,uint256 nonce,bytes data)');
  bytes32 internal constant DOMAIN_TYPEHASH =
    keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)');

  bool public lastTxSucceeded;
  mapping(address => uint256) public verifierSpaceOwnerKeys;

  constructor(
    SpaceRegistry _spaceRegistry,
    address[] memory _eoaActors,
    address[] memory _daoSpaceActors,
    address[] memory _verifierSpaceActors,
    uint256[] memory _verifierSpaceOwnerKeys
  ) BaseHandler(_spaceRegistry, _eoaActors, _daoSpaceActors, _verifierSpaceActors) {
    for (uint256 i = 0; i < _verifierSpaceActors.length; i++) {
      verifierSpaceOwnerKeys[_verifierSpaceActors[i]] = _verifierSpaceOwnerKeys[i];
    }
  }

  function handler_verifierSpace_enter(uint256 _verifierSpaceSeed, uint256 _toSpaceSeed) external {
    if (verifierSpaceActors.length == 0) {
      lastTxSucceeded = false;
      return;
    }

    address verifierSpace = verifierSpaceActors[bound(_verifierSpaceSeed, 0, verifierSpaceActors.length - 1)];
    address toSpace = _selectTargetSpace(_toSpaceSeed);
    if (toSpace == address(0)) {
      lastTxSucceeded = false;
      return;
    }

    uint256 ownerKey = verifierSpaceOwnerKeys[verifierSpace];
    if (ownerKey == 0) {
      lastTxSucceeded = false;
      return;
    }

    VerifierSpace vs = VerifierSpace(verifierSpace);
    uint256 nonceBefore = vs.replayNonce();
    ghost_lastNonceBefore[verifierSpace] = nonceBefore;

    bytes16 verifierSpaceId = spaceRegistry.addressToSpaceId(verifierSpace);
    bytes16 toSpaceId = spaceRegistry.addressToSpaceId(toSpace);

    bytes memory data = abi.encode('test');
    bytes memory signature = _signMessage(
      verifierSpace, ownerKey, toSpaceId, ActionsConstants.UPVOTED, bytes32(uint256(1)), nonceBefore, data
    );

    vm.prank(msg.sender);
    try spaceRegistry.enter(
      verifierSpaceId, toSpaceId, ActionsConstants.UPVOTED, bytes32(uint256(1)), data, signature
    ) {
      ghost_lastNonceAfter[verifierSpace] = vs.replayNonce();
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

    address verifierSpace = verifierSpaceActors[bound(_verifierSpaceSeed, 0, verifierSpaceActors.length - 1)];
    uint256 ownerKey = verifierSpaceOwnerKeys[verifierSpace];
    if (ownerKey == 0) {
      lastTxSucceeded = false;
      return;
    }

    uint256 currentNonce = VerifierSpace(verifierSpace).replayNonce();
    if (currentNonce == 0) {
      lastTxSucceeded = false;
      return;
    }

    bytes16 verifierSpaceId = spaceRegistry.addressToSpaceId(verifierSpace);

    uint256 oldNonce = currentNonce - 1;
    bytes memory data = abi.encode('replay');
    bytes memory signature = _signMessage(
      verifierSpace, ownerKey, verifierSpaceId, ActionsConstants.UPVOTED, bytes32(uint256(1)), oldNonce, data
    );

    vm.prank(msg.sender);
    try spaceRegistry.enter(
      verifierSpaceId, verifierSpaceId, ActionsConstants.UPVOTED, bytes32(uint256(1)), data, signature
    ) {
      ghost_replayAttackSucceeded = true;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function _selectTargetSpace(uint256 _seed) internal view returns (address _targetSpace) {
    uint256 totalSpaces = daoSpaceActors.length + verifierSpaceActors.length;
    if (totalSpaces == 0) return address(0);

    uint256 idx = bound(_seed, 0, totalSpaces - 1);
    if (idx < daoSpaceActors.length) {
      return daoSpaceActors[idx];
    }
    return verifierSpaceActors[idx - daoSpaceActors.length];
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
    bytes32 domainSeparator = _computeDomainSeparator(_verifierSpace);
    bytes32 structHash =
      keccak256(abi.encode(MESSAGE_TYPEHASH, _toSpaceId, _action, _subject, _nonce, keccak256(_data)));
    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', domainSeparator, structHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_ownerKey, digest);
    return abi.encodePacked(r, s, v);
  }

  function _computeDomainSeparator(address _verifierSpace) internal view returns (bytes32 _domainSeparator) {
    VerifierSpace vs = VerifierSpace(_verifierSpace);
    return keccak256(
      abi.encode(
        DOMAIN_TYPEHASH, keccak256(bytes(vs.name())), keccak256(bytes(vs.version())), block.chainid, _verifierSpace
      )
    );
  }
}
