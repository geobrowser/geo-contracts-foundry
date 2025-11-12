// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IDAO} from '@aragon/osx/core/dao/IDAO.sol';
import {IPermissionCondition, PermissionCondition} from '@aragon/osx/core/permission/PermissionCondition.sol';

import {MainVotingPlugin} from 'contracts/governance/MainVotingPlugin.sol';
import {IMemberAccessExecuteCondition} from 'interfaces/conditions/IMemberAccessExecuteCondition.sol';

/// @notice The condition associated with `TestSharedPlugin`
contract MemberAccessExecuteCondition is PermissionCondition, IMemberAccessExecuteCondition {
  /// @notice The address of the contract where the permission can be granted
  address private targetContract;

  /// @notice The constructor of the condition
  /// @param _targetContract The address of the contract where the permission can be granted
  constructor(address _targetContract) {
    targetContract = _targetContract;
  }

  /// @notice Checks whether the current action attempts to add members
  /// @inheritdoc IPermissionCondition
  function isGranted(
    address _where,
    address _who,
    bytes32 _permissionId,
    bytes calldata _data
  ) external view returns (bool) {
    (_where, _who, _permissionId);

    // Is it execute()?
    if (_getSelector(_data) != IDAO.execute.selector) {
      return false;
    }

    (, IDAO.Action[] memory _actions,) = abi.decode(_data[4:], (bytes32, IDAO.Action[], uint256));

    // Check actions
    if (_actions.length != 1) return false;
    else if (_actions[0].to != targetContract) return false;

    // Decode the call being requested (both have the same parameters)
    (bytes4 _requestedSelector,) = _decodeAddMemberCalldata(_actions[0].data);

    if (_requestedSelector != MainVotingPlugin.addMember.selector) return false;

    return true;
  }

  /// @notice Gets the function selector from raw data
  /// @param _data The raw data
  /// @return selector The function selector
  function _getSelector(bytes memory _data) internal pure returns (bytes4 selector) {
    // Slices are only supported for bytes calldata, not bytes memory
    // Bytes memory requires an assembly block
    assembly {
      selector := mload(add(_data, 0x20)) // 32
    }
  }

  /// @notice Decodes the calldata for adding a member
  /// @param _data The calldata for adding a member
  /// @return selector The function selector to add a member
  /// @return account The account to add as member
  function _decodeAddMemberCalldata(bytes memory _data) internal pure returns (bytes4 selector, address account) {
    // Slicing is only supported for bytes calldata, not bytes memory
    // Bytes memory requires an assembly block
    assembly {
      selector := mload(add(_data, 0x20)) // 32
      account := mload(add(_data, 0x24)) // 32 + 4
    }
  }
}
