// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Safe} from '@safe-global/safe-smart-account/Safe.sol';
import {CompatibilityFallbackHandler} from '@safe-global/safe-smart-account/handler/CompatibilityFallbackHandler.sol';
import {ISafe} from '@safe-global/safe-smart-account/interfaces/ISafe.sol';
import {Enum} from '@safe-global/safe-smart-account/libraries/Enum.sol';
import {SignMessageLib} from '@safe-global/safe-smart-account/libraries/SignMessageLib.sol';
import {SafeProxyFactory} from '@safe-global/safe-smart-account/proxies/SafeProxyFactory.sol';

import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {IVerifierSpace} from 'interfaces/IVerifierSpace.sol';

import 'src/ActionsConstants.sol' as ActionsConstants;

contract IntegrationSafe is IntegrationBase {
  Safe public safeSingleton;
  SafeProxyFactory public safeProxyFactory;
  CompatibilityFallbackHandler public fallbackHandler;
  SignMessageLib public signMessageLib;

  Safe public userSafe;
  VerifierSpace public verifierSpace;

  address[] internal _safeOwners;
  uint256[] internal _safeOwnersPrivateKeys;
  uint256 internal _safeThreshold;
  bytes16 internal _verifierSpaceId;
  bytes16[] internal _safeOwnerSpaceIds;

  function setUp() public override {
    IntegrationBase.setUp();
    vm.selectFork(_geoTestnetForkId);

    // Set up safe owners with their keys
    _safeOwners = new address[](2);
    _safeOwnersPrivateKeys = new uint256[](2);
    (_safeOwners[0], _safeOwnersPrivateKeys[0]) = makeAddrAndKey('safeOwner0');
    (_safeOwners[1], _safeOwnersPrivateKeys[1]) = makeAddrAndKey('safeOwner1');
    _safeThreshold = 1;

    // Deploy safe architecture
    safeSingleton = new Safe();
    safeProxyFactory = new SafeProxyFactory();
    fallbackHandler = new CompatibilityFallbackHandler();
    signMessageLib = new SignMessageLib();

    // Create safe with fallback handler set during setup
    bytes memory _initializer = abi.encodeCall(
      ISafe.setup,
      (_safeOwners, _safeThreshold, address(0), '', address(fallbackHandler), address(0), 0, payable(address(0)))
    );
    userSafe = Safe(payable(address(safeProxyFactory.createProxyWithNonce(address(safeSingleton), _initializer, 0))));

    // Deploy VerifierSpace with the safe as the owner
    verifierSpace = VerifierSpace(verifierSpaceFactoryProxy.createVerifierSpaceProxy(address(userSafe)));

    // Register space id for use below
    vm.prank(_safeOwners[0]);
    spaceRegistryProxy.registerSpaceId(keccak256('EOA_SPACE'), abi.encode('1.0.0'));

    // Set space IDs for use in tests
    _verifierSpaceId = spaceRegistryProxy.addressToSpaceId(address(verifierSpace));
    _safeOwnerSpaceIds = new bytes16[](2);
    _safeOwnerSpaceIds[0] = spaceRegistryProxy.addressToSpaceId(_safeOwners[0]);
    _safeOwnerSpaceIds[1] = spaceRegistryProxy.addressToSpaceId(_safeOwners[1]);
  }

  function test_SafeInit() external view {
    assertEq(userSafe.getOwners().length, _safeOwners.length);
    assertEq(userSafe.getOwners()[0], _safeOwners[0]);
    assertEq(userSafe.getOwners()[1], _safeOwners[1]);
    assertEq(userSafe.getThreshold(), _safeThreshold);
  }

  function test_VerifierSpace_SafeSignsAndEmitsEvent_WithPreApprovedHash() external {
    // Pre-approve the message using SignMessageLib
    /// @dev Use a permissionless action to isolate the verify logic
    bytes32 _verifierDigest = _getVerifierSpaceDigest(
      spaceRegistryProxy.addressToSpaceId(_safeOwners[0]), ActionsConstants.UPVOTED, bytes32(0), abi.encode('')
    );
    bytes memory _signMessageData = abi.encodeCall(SignMessageLib.signMessage, (abi.encode(_verifierDigest)));
    bytes32 _signTxHash = userSafe.getTransactionHash(
      address(signMessageLib),
      0,
      _signMessageData,
      Enum.Operation.DelegateCall,
      0,
      0,
      0,
      address(0),
      payable(address(0)),
      userSafe.nonce()
    );

    vm.prank(_safeOwners[0]);
    userSafe.approveHash(_signTxHash);
    bytes memory _signApprovedSig = abi.encodePacked(bytes32(uint256(uint160(_safeOwners[0]))), bytes32(0), uint8(1));

    userSafe.execTransaction(
      address(signMessageLib),
      0,
      _signMessageData,
      Enum.Operation.DelegateCall,
      0,
      0,
      0,
      address(0),
      payable(address(0)),
      _signApprovedSig
    );

    vm.expectEmit();
    emit ISpaceRegistry.Action(
      _verifierSpaceId, _safeOwnerSpaceIds[0], ActionsConstants.UPVOTED, bytes32(0), abi.encode('')
    );

    // Enter the space registry using the verify flow
    /// @dev Use empty signature given pre-approval
    spaceRegistryProxy.enter(
      _verifierSpaceId, _safeOwnerSpaceIds[0], ActionsConstants.UPVOTED, bytes32(0), abi.encode(''), ''
    );

    // Verify the replay nonce was incremented
    assertEq(verifierSpace.replayNonce(), 1);

    // Verify replay protection
    vm.expectRevert(IVerifierSpace.InvalidSignature.selector);
    spaceRegistryProxy.enter(
      _verifierSpaceId, _safeOwnerSpaceIds[0], ActionsConstants.UPVOTED, bytes32(0), abi.encode(''), ''
    );
  }

  function test_VerifierSpace_SafeSignsAndEmitsEvent_WithSignature() external {
    // Create a signature for the verify flow
    /// @dev Use a permissionless action to isolate the verify logic
    bytes32 _verifierDigest = _getVerifierSpaceDigest(
      spaceRegistryProxy.addressToSpaceId(_safeOwners[0]), ActionsConstants.UPVOTED, bytes32(0), abi.encode('')
    );
    bytes32 _safeMessageHash = fallbackHandler.getMessageHashForSafe(userSafe, abi.encode(_verifierDigest));
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_safeOwnersPrivateKeys[0], _safeMessageHash);
    bytes memory _signature = abi.encodePacked(_r, _s, _v);

    // Enter the space registry using the verify flow
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      _verifierSpaceId, _safeOwnerSpaceIds[0], ActionsConstants.UPVOTED, bytes32(0), abi.encode('')
    );

    spaceRegistryProxy.enter(
      _verifierSpaceId, _safeOwnerSpaceIds[0], ActionsConstants.UPVOTED, bytes32(0), abi.encode(''), _signature
    );

    // Verify the replay nonce was incremented
    assertEq(verifierSpace.replayNonce(), 1);

    // Verify replay protection
    vm.expectRevert(IVerifierSpace.InvalidSignature.selector);
    spaceRegistryProxy.enter(
      _verifierSpaceId, _safeOwnerSpaceIds[0], ActionsConstants.UPVOTED, bytes32(0), abi.encode(''), ''
    );
  }

  function _getVerifierSpaceDigest(
    bytes16 _toSpaceId,
    bytes32 _action,
    bytes32 _subject,
    bytes memory _data
  ) internal view returns (bytes32 _digest) {
    uint256 _replayNonce = verifierSpace.replayNonce();
    bytes32 _structHash = keccak256(
      abi.encode(verifierSpace.MESSAGE_TYPEHASH(), _toSpaceId, _action, _subject, _replayNonce, keccak256(_data))
    );
    bytes32 _domainSeparator = keccak256(
      abi.encode(
        keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
        keccak256(bytes(verifierSpace.name())),
        keccak256(bytes(verifierSpace.version())),
        block.chainid,
        address(verifierSpace)
      )
    );
    _digest = keccak256(abi.encodePacked('\x19\x01', _domainSeparator, _structHash));
  }
}
