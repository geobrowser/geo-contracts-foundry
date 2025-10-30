// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {IAccount} from 'interfaces/IAccount.sol';
import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/registry/ISpaceRegistry.sol';

/// @title SpaceRegistry
/// @notice Central registry for managing spaces
/// @dev This contract serves as the entry point for creating new spaces.
///      Each space has a unique ID that maps to an address.
///      Spaces can migrate to new addresses while keeping their ID.
contract SpaceRegistry is OwnableUpgradeable, UUPSUpgradeable, ISpaceRegistry {
  /// @inheritdoc ISpaceRegistry
  mapping(bytes16 => address) public spaceIdToAddress;

  /// @inheritdoc ISpaceRegistry
  mapping(address => bytes16) public addressToSpaceId;

  /// @inheritdoc ISpaceRegistry
  function initialize(address _owner) external initializer {
    _transferOwnership(_owner);
  }

  /// @inheritdoc ISpaceRegistry
  function enter(
    address _from,
    address _to,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external {
    // Translate addresses into space ids
    // Some check here that the space Ids exist? Maybe it's fine if it isn't registered?
    bytes32 spaces = bytes32(addressToSpaceId[_from] | addressToSpaceId[_to] >> 128);
    emit Ping(spaces, _action, _topic, _data);

    // If msg.sender is not the from
    // Then pass the to, action, topic, data, and signature for verification
    if (msg.sender != _from) IAccount(_from).verify(_to, _action, _topic, _data, _signature);

    // If msg.sender is not the to
    // Then pass the from, action, topic, and data to the space
    if (msg.sender != _to) ISpace(_to).write(_from, _action, _topic, _data);
  }

  /// @inheritdoc ISpaceRegistry
  function registerSpaceId(address _account) external {
    // REVIEW: What if an address gets frontrun?
    // Account must not be registered
    require(addressToSpaceId[_account] == bytes16(0));

    // REVIEW: After migration, old addresses will keep generating the same `spaceId`, rendering them unusable upon re-registration
    bytes16 spaceId = generateSpaceId(_account);

    // Space id must not be being used
    require(spaceIdToAddress[spaceId] == address(0));

    addressToSpaceId[_account] = spaceId;
    spaceIdToAddress[spaceId] = _account;

    // REVIEW: Do we need to emit a Ping here?
  }

  /// @inheritdoc ISpaceRegistry
  function migrateSpaceAddress(address _newAccount) external {
    // Must be called by the space itself
    bytes16 spaceId = addressToSpaceId[msg.sender];
    if (spaceId == bytes16(0)) revert SpaceRegistryInvalidCaller(msg.sender);

    // REVIEW: What if new address gets frontrun?
    // New address must not be registered
    require(addressToSpaceId[_newAccount] == bytes16(0));

    spaceIdToAddress[spaceId] = _newAccount;
    addressToSpaceId[msg.sender] = bytes16(0);
    addressToSpaceId[_newAccount] = spaceId;

    // REVIEW: Do we need to emit a Ping here?
  }

  /// @inheritdoc ISpaceRegistry
  function generateSpaceId(address _account) public view returns (bytes16 spaceId) {
    spaceId = bytes16(keccak256(abi.encodePacked('grc20.space', _account, block.chainid)));
  }

  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
