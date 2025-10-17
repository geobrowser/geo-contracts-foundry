// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {_uncheckedAdd, _uncheckedSub} from '@aragon/osx/utils/UncheckedMath.sol';
import {CheckpointsUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/CheckpointsUpgradeable.sol';

import {IAddresslist} from 'interfaces/governance/base/IAddresslist.sol';

/// @title Addresslist
/// @notice A list of member addresses.
abstract contract Addresslist is IAddresslist {
  using CheckpointsUpgradeable for CheckpointsUpgradeable.History;

  /// @notice The mapping containing the checkpointed history of the address list.
  mapping(address => CheckpointsUpgradeable.History) private _addresslistCheckpoints;

  /// @notice The checkpointed history of the length of the address list.
  CheckpointsUpgradeable.History private _addresslistLengthCheckpoints;

  /// @inheritdoc IAddresslist
  function isListedAtBlock(address _account, uint256 _blockNumber) public view virtual returns (bool) {
    return _addresslistCheckpoints[_account].getAtBlock(_blockNumber) == 1;
  }

  /// @inheritdoc IAddresslist
  function isListed(address _account) public view virtual returns (bool) {
    return _addresslistCheckpoints[_account].latest() == 1;
  }

  /// @inheritdoc IAddresslist
  function addresslistLengthAtBlock(uint256 _blockNumber) public view virtual returns (uint256) {
    return _addresslistLengthCheckpoints.getAtBlock(_blockNumber);
  }

  /// @inheritdoc IAddresslist
  function addresslistLength() public view virtual returns (uint256) {
    return _addresslistLengthCheckpoints.latest();
  }

  /// @notice Internal function to add new addresses to the address list.
  /// @param _newAddresses The new addresses to be added.
  function _addAddresses(address[] memory _newAddresses) internal virtual {
    for (uint256 i; i < _newAddresses.length;) {
      if (isListed(_newAddresses[i])) {
        revert InvalidAddresslistUpdate(_newAddresses[i]);
      }

      // Mark the address as listed
      _addresslistCheckpoints[_newAddresses[i]].push(1);

      unchecked {
        ++i;
      }
    }
    _addresslistLengthCheckpoints.push(_uncheckedAdd, _newAddresses.length);
  }

  /// @notice Internal function to remove existing addresses from the address list.
  /// @param _exitingAddresses The existing addresses to be removed.
  function _removeAddresses(address[] memory _exitingAddresses) internal virtual {
    for (uint256 i; i < _exitingAddresses.length;) {
      if (!isListed(_exitingAddresses[i])) {
        revert InvalidAddresslistUpdate(_exitingAddresses[i]);
      }

      // Mark the address as not listed
      _addresslistCheckpoints[_exitingAddresses[i]].push(0);

      unchecked {
        ++i;
      }
    }
    _addresslistLengthCheckpoints.push(_uncheckedSub, _exitingAddresses.length);
  }

  /// @dev This empty reserved space is put in place to allow future versions to add new
  /// variables without shifting down storage in the inheritance chain.
  /// https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
  uint256[48] private __gap;
}
