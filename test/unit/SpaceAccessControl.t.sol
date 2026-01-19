// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';
import {MockSpaceAccessControl} from 'test/unit/mocks/MockSpaceAccessControl.sol';

import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';

contract UnitSpaceAccessControl is TestHelper {
  MockSpaceAccessControl public spaceAccessControlImplementation;
  MockSpaceAccessControl public spaceAccessControlProxy;

  ISpaceRegistry internal _spaceRegistry = ISpaceRegistry(makeAddr('_spaceRegistry'));

  function setUp() external {
    // when deployed
    spaceAccessControlImplementation = new MockSpaceAccessControl();

    // when delegate called
    spaceAccessControlProxy = MockSpaceAccessControl(
      UnsafeUpgrades.deployUUPSProxy(
        address(spaceAccessControlImplementation),
        abi.encodeCall(MockSpaceAccessControl.initialize, (abi.encode(_spaceRegistry)))
      )
    );
  }

  function test_Constants_WhenDeployed() external view {
    // it sets _SPACE_ACCESS_CONTROL_STORAGE_LOCATION to keccak256(abi.encode(uint256(keccak256("geo.storage.SpaceAccessControl")) - 1)) & ~bytes32(uint256(0xff))
    assertEq(
      spaceAccessControlProxy.exposed__SPACE_ACCESS_CONTROL_STORAGE_LOCATION(),
      keccak256(abi.encode(uint256(keccak256('geo.storage.SpaceAccessControl')) - 1)) & ~bytes32(uint256(0xff))
    );
  }

  function test_GrantRole_WhenCalled(bytes32 _role, bytes16 _spaceId) external {
    vm.assume(_spaceId != bytes16(0));

    // when called
    spaceAccessControlProxy.workaround_grantRole(_role, _spaceId);

    // it grants _role to _spaceId
    assertTrue(spaceAccessControlProxy.hasRole(_role, _spaceId));
  }

  function test_RevokeRole_WhenCalled(bytes32 _role, bytes16 _spaceId) external {
    vm.assume(_spaceId != bytes16(0));

    // when _spaceId has the _role
    spaceAccessControlProxy.workaround_grantRole(_role, _spaceId);
    assertTrue(spaceAccessControlProxy.hasRole(_role, _spaceId));

    // when called
    spaceAccessControlProxy.workaround_revokeRole(_role, _spaceId);

    // it revokes _role from _spaceId
    assertFalse(spaceAccessControlProxy.hasRole(_role, _spaceId));
  }

  function _mockAddressToSpaceId(address __spaceRegistry, address __account, bytes16 __spaceId) internal {
    _mockAndExpect(__spaceRegistry, abi.encodeCall(ISpaceRegistry.addressToSpaceId, (__account)), abi.encode(__spaceId));
  }
}
