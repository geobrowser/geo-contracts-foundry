// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {TestHelper} from 'unit-helpers/TestHelper.sol';

import {ERC1967Utils} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol';
import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';

import {DAOSpace} from 'contracts/L3/DAOSpace.sol';
import {VerifierSpace} from 'contracts/L3/VerifierSpace.sol';
import {DeployL3Contracts} from 'script/L3/DeployL3Contracts.s.sol';

import 'script/Constants.sol' as Constants;

contract UnitDeployL3Contractsrun is TestHelper {
  DeployL3Contracts public deployL3Contracts;

  function setUp() external {
    deployL3Contracts = new DeployL3Contracts();
  }

  function test_WhenCalled() external {
    // when called
    deployL3Contracts.run();

    // it deploys DAOSpace implementation
    assertEq(address(deployL3Contracts.daoSpaceImplementation()).code, type(DAOSpace).runtimeCode);
    // it deploys VerifierSpace implementation
    assertEq(address(deployL3Contracts.verifierSpaceImplementation()).code, type(VerifierSpace).runtimeCode);

    // it deploys SpaceRegistry implementation
    assertEq(deployL3Contracts.spaceRegistryImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    assertEq(deployL3Contracts.spaceRegistryImplementation().name(), 'SPACE_REGISTRY');
    // it deploys and initializes SpaceRegistry proxy
    assertEq(
      address(
        uint160(uint256(vm.load(address(deployL3Contracts.spaceRegistryProxy()), ERC1967Utils.IMPLEMENTATION_SLOT)))
      ),
      address(deployL3Contracts.spaceRegistryImplementation())
    );
    assertEq(deployL3Contracts.spaceRegistryProxy().owner(), Constants.GEO_GEO_MULTISIG_COUNCIL);

    // it deploys DAOSpaceFactory implementation
    assertEq(deployL3Contracts.daoSpaceFactoryImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    assertEq(deployL3Contracts.daoSpaceFactoryImplementation().name(), 'DAO_SPACE_FACTORY');
    // it deploys and initializes DAOSpaceFactory proxy
    assertEq(
      address(
        uint160(uint256(vm.load(address(deployL3Contracts.daoSpaceFactoryProxy()), ERC1967Utils.IMPLEMENTATION_SLOT)))
      ),
      address(deployL3Contracts.daoSpaceFactoryImplementation())
    );
    assertEq(deployL3Contracts.daoSpaceFactoryProxy().owner(), Constants.GEO_GEO_MULTISIG_COUNCIL);
    assertEq(deployL3Contracts.daoSpaceFactoryProxy().daoSpaceBeacon(), address(deployL3Contracts.daoSpaceBeacon()));
    assertEq(
      address(deployL3Contracts.daoSpaceFactoryProxy().spaceRegistry()), address(deployL3Contracts.spaceRegistryProxy())
    );
    // it deploys DAOSpace beacon
    assertEq(address(deployL3Contracts.daoSpaceBeacon()).code, type(UpgradeableBeacon).runtimeCode);
    assertEq(deployL3Contracts.daoSpaceBeacon().owner(), Constants.GEO_GEO_MULTISIG_COUNCIL);
    assertEq(deployL3Contracts.daoSpaceBeacon().implementation(), address(deployL3Contracts.daoSpaceImplementation()));

    // it deploys VerifierSpaceFactory implementation
    assertEq(deployL3Contracts.verifierSpaceFactoryImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    assertEq(deployL3Contracts.verifierSpaceFactoryImplementation().name(), 'VERIFIER_SPACE_FACTORY');
    // it deploys and initializes VerifierSpaceFactory proxy
    assertEq(
      address(
        uint160(
          uint256(vm.load(address(deployL3Contracts.verifierSpaceFactoryProxy()), ERC1967Utils.IMPLEMENTATION_SLOT))
        )
      ),
      address(deployL3Contracts.verifierSpaceFactoryImplementation())
    );
    assertEq(deployL3Contracts.verifierSpaceFactoryProxy().owner(), Constants.GEO_GEO_MULTISIG_COUNCIL);
    assertEq(
      deployL3Contracts.verifierSpaceFactoryProxy().verifierSpaceBeacon(),
      address(deployL3Contracts.verifierSpaceBeacon())
    );
    assertEq(
      address(deployL3Contracts.verifierSpaceFactoryProxy().spaceRegistry()),
      address(deployL3Contracts.spaceRegistryProxy())
    );
    // it deploys VerifierSpace beacon
    assertEq(address(deployL3Contracts.verifierSpaceBeacon()).code, type(UpgradeableBeacon).runtimeCode);
    assertEq(deployL3Contracts.verifierSpaceBeacon().owner(), Constants.GEO_GEO_MULTISIG_COUNCIL);
    assertEq(
      deployL3Contracts.verifierSpaceBeacon().implementation(), address(deployL3Contracts.verifierSpaceImplementation())
    );
  }
}
