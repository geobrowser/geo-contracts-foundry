// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISpace} from 'interfaces/core/ISpace.sol';

contract DAOSpace is ISpace {
  bytes32 public constant ADD_EDITOR = keccak256('ADD_EDITOR');
  bytes32 public constant REMOVE_EDITOR = keccak256('REMOVE_EDITOR');
  bytes32 public constant ADD_MEMBER = keccak256('ADD_MEMBER');

  //...

  /// @dev Universal entrypoint for the DAO space
  /// @dev Maybe some access control so only callable by the Emitter
  function write(address _account, bytes32 _action, bytes32 _topic, bytes calldata _data) external {
    if (_action == ADD_EDITOR) _addEditor(_account, _topic, _data);
    if (_action == REMOVE_EDITOR) _removeEditor(_account, _topic, _data);
    if (_action == ADD_MEMBER) _addMember(_account, _topic, _data);
    //...
  }

  // Some logic later
  function _addEditor(address _account, bytes32 _topic, bytes calldata _data) internal {}
  function _removeEditor(address _account, bytes32 _topic, bytes calldata _data) internal {}
  function _addMember(address _account, bytes32 _topic, bytes calldata _data) internal {}
  //...
}
