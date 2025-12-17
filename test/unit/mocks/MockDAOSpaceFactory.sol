// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {DAOSpaceFactory} from 'contracts/DAOSpaceFactory.sol';

/**
 * @title MockDAOSpaceFactory
 * @notice Mock contract for testing DAOSpaceFactory with additional test helper functions
 */
contract MockDAOSpaceFactory is DAOSpaceFactory {
  function exposed__authorizeUpgrade(address _newImplementation) external {
    _authorizeUpgrade(_newImplementation);
  }

  function exposed__DAO_SPACE_FACTORY_STORAGE_LOCATION()
    external
    pure
    returns (bytes32 _daoSpaceFactoryStorageLocation)
  {
    _daoSpaceFactoryStorageLocation = _DAO_SPACE_FACTORY_STORAGE_LOCATION;
  }
}
