// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';
import {MockSpaceAccessControl} from 'test/unit/mocks/MockSpaceAccessControl.sol';

import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {ISpaceAccessControl} from 'interfaces/utils/ISpaceAccessControl.sol';

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

    assertEq(address(spaceAccessControlProxy.spaceRegistry()), address(_spaceRegistry));
  }

  function test_Constants_WhenDeployed() external view {
    // it sets _SPACE_ACCESS_CONTROL_STORAGE_LOCATION to keccak256(abi.encode(uint256(keccak256("geo.storage.SpaceAccessControl")) - 1)) & ~bytes32(uint256(0xff))
    assertEq(
      spaceAccessControlProxy.exposed__SPACE_ACCESS_CONTROL_STORAGE_LOCATION(),
      keccak256(abi.encode(uint256(keccak256('geo.storage.SpaceAccessControl')) - 1)) & ~bytes32(uint256(0xff))
    );
  }

  function test_GrantRole_When_accountIsNotRegistered(bytes32 _role, address _account) external {
    _mockAddressToSpaceId(address(_spaceRegistry), _account, bytes16(0));

    // it reverts with SpaceNotRegistered
    vm.expectRevert(ISpaceAccessControl.SpaceNotRegistered.selector);
    spaceAccessControlProxy.workaround_grantRole(_role, _account);
  }

  function test_GrantRole_When_spaceIdAlreadyHasThe_role(bytes32 _role, address _account, bytes16 _spaceId) external {
    vm.assume(_spaceId != bytes16(0));
    _mockAddressToSpaceId(address(_spaceRegistry), _account, _spaceId);

    // when _spaceId already has the _role
    assertEq(spaceAccessControlProxy.workaround_grantRole(_role, _account), _spaceId);

    _mockAddressToSpaceId(address(_spaceRegistry), _account, _spaceId);

    // it returns the _spaceId
    assertEq(spaceAccessControlProxy.workaround_grantRole(_role, _account), _spaceId);
  }

  function test_GrantRole_When_spaceIdDoesNotHaveThe_role(bytes32 _role, address _account, bytes16 _spaceId) external {
    vm.assume(_spaceId != bytes16(0));
    _mockAddressToSpaceId(address(_spaceRegistry), _account, _spaceId);

    // when _spaceId does not have the _role
    assertEq(spaceAccessControlProxy.hasRole(_role, _account), false);

    _mockAddressToSpaceId(address(_spaceRegistry), _account, _spaceId);

    // it returns the _spaceId
    assertEq(spaceAccessControlProxy.workaround_grantRole(_role, _account), _spaceId);

    _mockAddressToSpaceId(address(_spaceRegistry), _account, _spaceId);

    // it grants _role to _spaceId
    assertEq(spaceAccessControlProxy.hasRole(_role, _account), true);
  }

  function test_RevokeRole_When_accountIsNotRegistered(bytes32 _role, address _account) external {
    _mockAddressToSpaceId(address(_spaceRegistry), _account, bytes16(0));

    // it reverts with SpaceNotRegistered
    vm.expectRevert(ISpaceAccessControl.SpaceNotRegistered.selector);
    spaceAccessControlProxy.workaround_revokeRole(_role, _account);
  }

  function test_RevokeRole_When_spaceIdDoesNotHaveThe_role(bytes32 _role, address _account, bytes16 _spaceId) external {
    vm.assume(_spaceId != bytes16(0));
    _mockAddressToSpaceId(address(_spaceRegistry), _account, _spaceId);

    // when _spaceId does not have the _role
    assertEq(spaceAccessControlProxy.hasRole(_role, _account), false);

    _mockAddressToSpaceId(address(_spaceRegistry), _account, _spaceId);

    // it returns the _spaceId
    assertEq(spaceAccessControlProxy.workaround_revokeRole(_role, _account), _spaceId);
  }

  function test_RevokeRole_When_spaceIdHasThe_role(bytes32 _role, address _account, bytes16 _spaceId) external {
    vm.assume(_spaceId != bytes16(0));
    _mockAddressToSpaceId(address(_spaceRegistry), _account, _spaceId);

    // when _spaceId has the _role
    assertEq(spaceAccessControlProxy.workaround_grantRole(_role, _account), _spaceId);

    _mockAddressToSpaceId(address(_spaceRegistry), _account, _spaceId);

    // it returns the _spaceId
    assertEq(spaceAccessControlProxy.workaround_revokeRole(_role, _account), _spaceId);

    _mockAddressToSpaceId(address(_spaceRegistry), _account, _spaceId);

    // it revokes _role from _spaceId
    assertEq(spaceAccessControlProxy.hasRole(_role, _account), false);
  }

  function _mockAddressToSpaceId(address __spaceRegistry, address __account, bytes16 __spaceId) internal {
    _mockAndExpect(__spaceRegistry, abi.encodeCall(ISpaceRegistry.addressToSpaceId, (__account)), abi.encode(__spaceId));
  }
}
