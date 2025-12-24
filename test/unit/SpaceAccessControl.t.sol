// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {MockSpaceAccessControl} from 'test/unit/mocks/MockSpaceAccessControl.sol';

contract UnitSpaceAccessControl is TestHelper {
  MockSpaceAccessControl public spaceAccessControl;

  function setUp() external {
    // when deployed
    spaceAccessControl = new MockSpaceAccessControl();
  }

  function test_Constants_WhenDeployed() external view {
    // it sets _SPACE_ACCESS_CONTROL_STORAGE_LOCATION to keccak256(abi.encode(uint256(keccak256("geo.storage.SpaceAccessControl")) - 1)) & ~bytes32(uint256(0xff))
    assertEq(
      spaceAccessControl.exposed__SPACE_ACCESS_CONTROL_STORAGE_LOCATION(),
      keccak256(abi.encode(uint256(keccak256('geo.storage.SpaceAccessControl')) - 1)) & ~bytes32(uint256(0xff))
    );
  }

  function test_GrantRole_When_spaceIdDoesNotHaveThe_role(bytes32 _role, bytes16 _spaceId) external {
    // when spaceid does not have the role
    assertEq(spaceAccessControl.hasRole(_role, _spaceId), false);

    // it returns true
    assertEq(spaceAccessControl.workaround_grantRole(_role, _spaceId), true);

    // it grants _role to _spaceId
    assertEq(spaceAccessControl.hasRole(_role, _spaceId), true);
  }

  function test_GrantRole_When_spaceIdAlreadyHasThe_role(bytes32 _role, bytes16 _spaceId) external {
    // when spaceid already has the role
    assertEq(spaceAccessControl.workaround_grantRole(_role, _spaceId), true);

    // it returns false
    assertEq(spaceAccessControl.workaround_grantRole(_role, _spaceId), false);
  }

  function test_RevokeRole_When_spaceIdHasThe_role(bytes32 _role, bytes16 _spaceId) external {
    // when spaceid has the role
    assertEq(spaceAccessControl.workaround_grantRole(_role, _spaceId), true);

    // it returns true
    assertEq(spaceAccessControl.workaround_revokeRole(_role, _spaceId), true);

    // it revokes _role from _spaceId
    assertEq(spaceAccessControl.hasRole(_role, _spaceId), false);
  }

  function test_RevokeRole_When_spaceIdDoesNotHaveThe_role(bytes32 _role, bytes16 _spaceId) external {
    // when spaceId does not have the role
    assertEq(spaceAccessControl.hasRole(_role, _spaceId), false);

    // it returns false
    assertEq(spaceAccessControl.workaround_revokeRole(_role, _spaceId), false);
  }
}
