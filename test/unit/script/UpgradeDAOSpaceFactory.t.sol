// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {ERC1967Utils} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol';

import {DAOSpaceFactory} from 'contracts/DAOSpaceFactory.sol';
import {UpgradeDAOSpaceFactory} from 'script/UpgradeDAOSpaceFactory.s.sol';

import 'script/Constants.s.sol' as Constants;

contract UnitUpgradeDAOSpaceFactoryrun is TestHelper {
  UpgradeDAOSpaceFactory public upgradeDAOSpaceFactory;

  function setUp() external {
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

    upgradeDAOSpaceFactory = new UpgradeDAOSpaceFactory();
  }

  function test_WhenCalled() external {
    assertEq(
      address(uint160(uint256(vm.load(Constants.GEO_DAO_SPACE_FACTORY_PROXY, ERC1967Utils.IMPLEMENTATION_SLOT)))),
      Constants.GEO_DAO_SPACE_FACTORY_IMPLEMENTATION
    );

    // when called
    upgradeDAOSpaceFactory.run();

    // it deploys DAOSpaceFactory implementation
    assertEq(upgradeDAOSpaceFactory.daoSpaceFactoryImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    assertEq(upgradeDAOSpaceFactory.daoSpaceFactoryImplementation().name(), 'DAO_SPACE_FACTORY');

    // it upgrades DAOSpaceFactory proxy
    assertEq(
      address(uint160(uint256(vm.load(Constants.GEO_DAO_SPACE_FACTORY_PROXY, ERC1967Utils.IMPLEMENTATION_SLOT)))),
      address(upgradeDAOSpaceFactory.daoSpaceFactoryImplementation())
    );
    assertNotEq(
      address(upgradeDAOSpaceFactory.daoSpaceFactoryImplementation()), Constants.GEO_DAO_SPACE_FACTORY_IMPLEMENTATION
    );
  }
}
