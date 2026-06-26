// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {VerifierSpaceFactory} from 'contracts/L3/VerifierSpaceFactory.sol';

/**
 * @title MockVerifierSpaceFactory
 * @notice Mock contract for testing VerifierSpaceFactory with additional test helper functions
 */
contract MockVerifierSpaceFactory is VerifierSpaceFactory {
  function exposed__authorizeUpgrade(address _newImplementation) external {
    _authorizeUpgrade(_newImplementation);
  }

  function exposed__VERIFIER_SPACE_FACTORY_STORAGE_LOCATION()
    external
    pure
    returns (bytes32 _verifierSpaceFactoryStorageLocation)
  {
    _verifierSpaceFactoryStorageLocation = _VERIFIER_SPACE_FACTORY_STORAGE_LOCATION;
  }
}
