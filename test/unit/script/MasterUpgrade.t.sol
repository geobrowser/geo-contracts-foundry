// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {ERC1967Utils} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol';
import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {DAOSpaceFactory} from 'contracts/DAOSpaceFactory.sol';
import {SpaceRegistry} from 'contracts/SpaceRegistry.sol';
import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {VerifierSpaceFactory} from 'contracts/VerifierSpaceFactory.sol';
import {MasterUpgrade} from 'script/MasterUpgrade.s.sol';

import 'script/Constants.s.sol' as Constants;

contract UnitMasterUpgraderun is TestHelper {
  MasterUpgrade public masterUpgrade;

  function setUp() external {
    deployCodeTo('SpaceRegistry.sol:SpaceRegistry', Constants.GEO_SPACE_REGISTRY_IMPLEMENTATION);
    deployCodeTo(
      'ERC1967Proxy.sol:ERC1967Proxy',
      abi.encode(
        Constants.GEO_SPACE_REGISTRY_IMPLEMENTATION,
        abi.encodeCall(SpaceRegistry.initialize, (abi.encode(Constants.GEO_GEO_MULTISIG_COUNCIL)))
      ),
      Constants.GEO_SPACE_REGISTRY_PROXY
    );
    deployCodeTo('DAOSpace.sol:DAOSpace', Constants.GEO_DAO_SPACE_IMPLEMENTATION);
    deployCodeTo('DAOSpaceFactory.sol:DAOSpaceFactory', Constants.GEO_DAO_SPACE_FACTORY_IMPLEMENTATION);
    deployCodeTo(
      'ERC1967Proxy.sol:ERC1967Proxy',
      abi.encode(
        Constants.GEO_DAO_SPACE_FACTORY_IMPLEMENTATION,
        abi.encodeCall(
          DAOSpaceFactory.initialize,
          (abi.encode(
              Constants.GEO_SPACE_REGISTRY_PROXY,
              Constants.GEO_GEO_MULTISIG_COUNCIL,
              Constants.GEO_DAO_SPACE_IMPLEMENTATION
            ))
        )
      ),
      Constants.GEO_DAO_SPACE_FACTORY_PROXY
    );
    deployCodeTo(
      'UpgradeableBeacon.sol:UpgradeableBeacon',
      abi.encode(Constants.GEO_DAO_SPACE_IMPLEMENTATION, Constants.GEO_GEO_MULTISIG_COUNCIL),
      Constants.GEO_DAO_SPACE_BEACON
    );
    deployCodeTo('VerifierSpace.sol:VerifierSpace', Constants.GEO_VERIFIER_SPACE_IMPLEMENTATION);
    deployCodeTo('VerifierSpaceFactory.sol:VerifierSpaceFactory', Constants.GEO_VERIFIER_SPACE_FACTORY_IMPLEMENTATION);
    deployCodeTo(
      'ERC1967Proxy.sol:ERC1967Proxy',
      abi.encode(
        Constants.GEO_VERIFIER_SPACE_FACTORY_IMPLEMENTATION,
        abi.encodeCall(
          VerifierSpaceFactory.initialize,
          (abi.encode(
              Constants.GEO_SPACE_REGISTRY_PROXY,
              Constants.GEO_GEO_MULTISIG_COUNCIL,
              Constants.GEO_VERIFIER_SPACE_IMPLEMENTATION
            ))
        )
      ),
      Constants.GEO_VERIFIER_SPACE_FACTORY_PROXY
    );
    deployCodeTo(
      'UpgradeableBeacon.sol:UpgradeableBeacon',
      abi.encode(Constants.GEO_VERIFIER_SPACE_IMPLEMENTATION, Constants.GEO_GEO_MULTISIG_COUNCIL),
      Constants.GEO_VERIFIER_SPACE_BEACON
    );

    masterUpgrade = new MasterUpgrade();
  }

  function test_WhenCalled() external {
    assertEq(
      address(uint160(uint256(vm.load(Constants.GEO_SPACE_REGISTRY_PROXY, ERC1967Utils.IMPLEMENTATION_SLOT)))),
      Constants.GEO_SPACE_REGISTRY_IMPLEMENTATION
    );
    assertEq(
      address(uint160(uint256(vm.load(Constants.GEO_DAO_SPACE_FACTORY_PROXY, ERC1967Utils.IMPLEMENTATION_SLOT)))),
      Constants.GEO_DAO_SPACE_FACTORY_IMPLEMENTATION
    );
    assertEq(
      address(uint160(uint256(vm.load(Constants.GEO_VERIFIER_SPACE_FACTORY_PROXY, ERC1967Utils.IMPLEMENTATION_SLOT)))),
      Constants.GEO_VERIFIER_SPACE_FACTORY_IMPLEMENTATION
    );
    assertEq(UpgradeableBeacon(Constants.GEO_DAO_SPACE_BEACON).implementation(), Constants.GEO_DAO_SPACE_IMPLEMENTATION);
    assertEq(
      UpgradeableBeacon(Constants.GEO_VERIFIER_SPACE_BEACON).implementation(),
      Constants.GEO_VERIFIER_SPACE_IMPLEMENTATION
    );

    // when called
    masterUpgrade.run();

    // it deploys SpaceRegistry implementation
    assertEq(masterUpgrade.spaceRegistryImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    assertEq(masterUpgrade.spaceRegistryImplementation().name(), 'SPACE_REGISTRY');

    // it upgrades SpaceRegistry proxy
    assertEq(
      address(uint160(uint256(vm.load(Constants.GEO_SPACE_REGISTRY_PROXY, ERC1967Utils.IMPLEMENTATION_SLOT)))),
      address(masterUpgrade.spaceRegistryImplementation())
    );
    assertNotEq(address(masterUpgrade.spaceRegistryImplementation()), Constants.GEO_SPACE_REGISTRY_IMPLEMENTATION);

    // it deploys DAOSpaceFactory implementation
    assertEq(masterUpgrade.daoSpaceFactoryImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    assertEq(masterUpgrade.daoSpaceFactoryImplementation().name(), 'DAO_SPACE_FACTORY');

    // it upgrades DAOSpaceFactory proxy
    assertEq(
      address(uint160(uint256(vm.load(Constants.GEO_DAO_SPACE_FACTORY_PROXY, ERC1967Utils.IMPLEMENTATION_SLOT)))),
      address(masterUpgrade.daoSpaceFactoryImplementation())
    );
    assertNotEq(address(masterUpgrade.daoSpaceFactoryImplementation()), Constants.GEO_DAO_SPACE_FACTORY_IMPLEMENTATION);

    // it deploys VerifierSpaceFactory implementation
    assertEq(masterUpgrade.verifierSpaceFactoryImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    assertEq(masterUpgrade.verifierSpaceFactoryImplementation().name(), 'VERIFIER_SPACE_FACTORY');

    // it upgrades VerifierSpaceFactory proxy
    assertEq(
      address(uint160(uint256(vm.load(Constants.GEO_VERIFIER_SPACE_FACTORY_PROXY, ERC1967Utils.IMPLEMENTATION_SLOT)))),
      address(masterUpgrade.verifierSpaceFactoryImplementation())
    );
    assertNotEq(
      address(masterUpgrade.verifierSpaceFactoryImplementation()), Constants.GEO_VERIFIER_SPACE_FACTORY_IMPLEMENTATION
    );

    // it deploys DAOSpace implementation
    assertEq(address(masterUpgrade.daoSpaceImplementation()).code, type(DAOSpace).runtimeCode);

    // it upgrades DAOSpace beacon
    assertEq(
      UpgradeableBeacon(Constants.GEO_DAO_SPACE_BEACON).implementation(),
      address(masterUpgrade.daoSpaceImplementation())
    );
    assertNotEq(address(masterUpgrade.daoSpaceImplementation()), Constants.GEO_DAO_SPACE_IMPLEMENTATION);

    // it deploys VerifierSpace implementation
    assertEq(address(masterUpgrade.verifierSpaceImplementation()).code, type(VerifierSpace).runtimeCode);

    // it upgrades VerifierSpace beacon
    assertEq(
      UpgradeableBeacon(Constants.GEO_VERIFIER_SPACE_BEACON).implementation(),
      address(masterUpgrade.verifierSpaceImplementation())
    );
    assertNotEq(address(masterUpgrade.verifierSpaceImplementation()), Constants.GEO_VERIFIER_SPACE_IMPLEMENTATION);
  }
}
