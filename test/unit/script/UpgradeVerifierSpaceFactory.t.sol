// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {ERC1967Utils} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol';

import {VerifierSpaceFactory} from 'contracts/VerifierSpaceFactory.sol';
import {UpgradeVerifierSpaceFactory} from 'script/UpgradeVerifierSpaceFactory.s.sol';

import 'script/Constants.s.sol' as Constants;

contract UnitUpgradeVerifierSpaceFactoryrun is TestHelper {
  UpgradeVerifierSpaceFactory public upgradeVerifierSpaceFactory;

  function setUp() external {
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

    upgradeVerifierSpaceFactory = new UpgradeVerifierSpaceFactory();
  }

  function test_WhenCalled() external {
    assertEq(
      address(uint160(uint256(vm.load(Constants.GEO_VERIFIER_SPACE_FACTORY_PROXY, ERC1967Utils.IMPLEMENTATION_SLOT)))),
      Constants.GEO_VERIFIER_SPACE_FACTORY_IMPLEMENTATION
    );

    // when called
    upgradeVerifierSpaceFactory.run();

    // it deploys VerifierSpaceFactory implementation
    assertEq(
      upgradeVerifierSpaceFactory.verifierSpaceFactoryImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT
    );
    assertEq(upgradeVerifierSpaceFactory.verifierSpaceFactoryImplementation().name(), 'VERIFIER_SPACE_FACTORY');

    // it upgrades VerifierSpaceFactory proxy
    assertEq(
      address(uint160(uint256(vm.load(Constants.GEO_VERIFIER_SPACE_FACTORY_PROXY, ERC1967Utils.IMPLEMENTATION_SLOT)))),
      address(upgradeVerifierSpaceFactory.verifierSpaceFactoryImplementation())
    );
    assertNotEq(
      address(upgradeVerifierSpaceFactory.verifierSpaceFactoryImplementation()),
      Constants.GEO_VERIFIER_SPACE_FACTORY_IMPLEMENTATION
    );
  }
}
