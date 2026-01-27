// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {ERC1967Utils} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol';
import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {DeployGEOBrowser} from 'script/DeployGEOBrowser.s.sol';

import 'script/Constants.s.sol' as Constants;

contract UnitDeployGEOBrowserrun is TestHelper {
  DeployGEOBrowser public deployGEOBrowser;

  function setUp() external {
    deployGEOBrowser = new DeployGEOBrowser();
  }

  function test_WhenCalled() external {
    // when called
    deployGEOBrowser.run();

    // it deploys DAOSpace implementation
    assertEq(address(deployGEOBrowser.daoSpaceImplementation()).code, type(DAOSpace).runtimeCode);
    // it deploys VerifierSpace implementation
    assertEq(address(deployGEOBrowser.verifierSpaceImplementation()).code, type(VerifierSpace).runtimeCode);

    // it deploys SpaceRegistry implementation
    assertEq(deployGEOBrowser.spaceRegistryImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    // it deploys and initializes SpaceRegistry proxy
    assertEq(
      address(
        uint160(uint256(vm.load(address(deployGEOBrowser.spaceRegistryProxy()), ERC1967Utils.IMPLEMENTATION_SLOT)))
      ),
      address(deployGEOBrowser.spaceRegistryImplementation())
    );
    assertEq(deployGEOBrowser.spaceRegistryProxy().owner(), Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL);

    // it deploys DAOSpaceFactory implementation
    assertEq(deployGEOBrowser.daoSpaceFactoryImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    // it deploys and initializes DAOSpaceFactory proxy
    assertEq(
      address(
        uint160(uint256(vm.load(address(deployGEOBrowser.daoSpaceFactoryProxy()), ERC1967Utils.IMPLEMENTATION_SLOT)))
      ),
      address(deployGEOBrowser.daoSpaceFactoryImplementation())
    );
    assertEq(deployGEOBrowser.daoSpaceFactoryProxy().owner(), Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL);
    assertEq(deployGEOBrowser.daoSpaceFactoryProxy().daoSpaceBeacon(), address(deployGEOBrowser.daoSpaceBeacon()));
    assertEq(
      address(deployGEOBrowser.daoSpaceFactoryProxy().spaceRegistry()), address(deployGEOBrowser.spaceRegistryProxy())
    );
    // it deploys DAOSpace beacon
    assertEq(address(deployGEOBrowser.daoSpaceBeacon()).code, type(UpgradeableBeacon).runtimeCode);
    assertEq(deployGEOBrowser.daoSpaceBeacon().owner(), Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL);
    assertEq(deployGEOBrowser.daoSpaceBeacon().implementation(), address(deployGEOBrowser.daoSpaceImplementation()));

    // it deploys VerifierSpaceFactory implementation
    assertEq(deployGEOBrowser.verifierSpaceFactoryImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    // it deploys and initializes VerifierSpaceFactory proxy
    assertEq(
      address(
        uint160(
          uint256(vm.load(address(deployGEOBrowser.verifierSpaceFactoryProxy()), ERC1967Utils.IMPLEMENTATION_SLOT))
        )
      ),
      address(deployGEOBrowser.verifierSpaceFactoryImplementation())
    );
    assertEq(deployGEOBrowser.verifierSpaceFactoryProxy().owner(), Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL);
    assertEq(
      deployGEOBrowser.verifierSpaceFactoryProxy().verifierSpaceBeacon(),
      address(deployGEOBrowser.verifierSpaceBeacon())
    );
    assertEq(
      address(deployGEOBrowser.verifierSpaceFactoryProxy().spaceRegistry()),
      address(deployGEOBrowser.spaceRegistryProxy())
    );
    // it deploys VerifierSpace beacon
    assertEq(address(deployGEOBrowser.verifierSpaceBeacon()).code, type(UpgradeableBeacon).runtimeCode);
    assertEq(deployGEOBrowser.verifierSpaceBeacon().owner(), Constants.GEO_TESTNET_GEO_MULTISIG_COUNCIL);
    assertEq(
      deployGEOBrowser.verifierSpaceBeacon().implementation(), address(deployGEOBrowser.verifierSpaceImplementation())
    );
  }
}
