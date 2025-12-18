// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {DAOSpace} from 'contracts/DAOSpace.sol';

/**
 * @title MockDAOSpaceV2
 * @notice Mock contract for testing new DAOSpace implementations
 */
contract MockDAOSpaceV2 is DAOSpace {
  function initialize(bytes calldata) external virtual override reinitializer(2) {
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    $.actionIsFastPathValid[DAOSpace.addMember.selector] = false;
    $.actionIsFastPathValid[DAOSpace.removeMember.selector] = false;
    $.actionIsFastPathValid[DAOSpace.addEditor.selector] = true;
    $.actionIsFastPathValid[DAOSpace.removeEditor.selector] = true;
  }

  function version() public pure virtual override returns (string memory _version) {
    _version = '2.0.0';
  }
}
