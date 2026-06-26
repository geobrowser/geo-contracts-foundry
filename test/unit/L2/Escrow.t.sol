// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';
import {Escrow} from 'contracts/L2/Escrow.sol';
import {IEscrow} from 'interfaces/L2/IEscrow.sol';
import {MockEscrow} from 'test/unit/L2/mocks/MockEscrow.sol';
import {TestHelper} from 'unit-helpers/TestHelper.sol';

contract UnitEscrow is TestHelper {
  address public council = makeAddr('council');

  address public alice = makeAddr('alice');
  address public rewarderAddr = makeAddr('rewarderAddr');

  address public arbitrumGeoToken = makeAddr('arbitrumGeoToken');
  MockEscrow public escrowImplementation;
  MockEscrow public escrowProxy;

  function setUp() external {
    escrowImplementation = new MockEscrow();
    escrowProxy = MockEscrow(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(escrowImplementation),
          abi.encodeCall(
            Escrow.initialize,
            (IEscrow.EscrowInitializationParams({
                arbitrumGeoToken: arbitrumGeoToken, council: council, rewarder: rewarderAddr
              }))
          )
        ))
    );
  }

  // -------- constants --------
  function test_Constants_WhenDeployed() external view {
    // when deployed
    // it sets _ESCROW_STORAGE_LOCATION to keccak256(abi.encode(uint256(keccak256("geo.storage.Escrow")) - 1)) & ~bytes32(uint256(0xff))
    assertEq(
      escrowImplementation.exposed__ESCROW_STORAGE_LOCATION(),
      keccak256(abi.encode(uint256(keccak256('geo.storage.Escrow')) - 1)) & ~bytes32(uint256(0xff))
    );
  }

  // -------- constructor --------
  function test_Constructor_WhenCalled() external {
    // when called
    // it disables initializers
    Escrow newImplementation = new Escrow();
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    newImplementation.initialize(
      IEscrow.EscrowInitializationParams({arbitrumGeoToken: arbitrumGeoToken, council: council, rewarder: rewarderAddr})
    );
  }

  // -------- initialize --------
  function test_Initialize_WhenArbitrumGeoTokenIsZero() external {
    // when arbitrumGeoToken is zero
    // it reverts with InvalidAddress
    escrowImplementation = new MockEscrow();
    vm.expectRevert(IEscrow.InvalidAddress.selector);
    UnsafeUpgrades.deployUUPSProxy(
      address(escrowImplementation),
      abi.encodeCall(
        Escrow.initialize,
        (IEscrow.EscrowInitializationParams({arbitrumGeoToken: address(0), council: council, rewarder: rewarderAddr}))
      )
    );
  }

  function test_Initialize_WhenCouncilIsZero() external {
    // when council is zero
    // it reverts with OwnableInvalidOwner
    escrowImplementation = new MockEscrow();
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
    UnsafeUpgrades.deployUUPSProxy(
      address(escrowImplementation),
      abi.encodeCall(
        Escrow.initialize,
        (IEscrow.EscrowInitializationParams({
            arbitrumGeoToken: arbitrumGeoToken, council: address(0), rewarder: rewarderAddr
          }))
      )
    );
  }

  function test_Initialize_WhenRewarderIsZero() external {
    // when rewarder is zero
    // it reverts with InvalidAddress
    escrowImplementation = new MockEscrow();
    vm.expectRevert(IEscrow.InvalidAddress.selector);
    UnsafeUpgrades.deployUUPSProxy(
      address(escrowImplementation),
      abi.encodeCall(
        Escrow.initialize,
        (IEscrow.EscrowInitializationParams({
            arbitrumGeoToken: arbitrumGeoToken, council: council, rewarder: address(0)
          }))
      )
    );
  }

  function test_Initialize_WhenCalled() external {
    // when called
    escrowImplementation = new MockEscrow();
    MockEscrow freshEscrow = MockEscrow(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(escrowImplementation),
          abi.encodeCall(
            Escrow.initialize,
            (IEscrow.EscrowInitializationParams({
                arbitrumGeoToken: arbitrumGeoToken, council: council, rewarder: rewarderAddr
              }))
          )
        ))
    );

    // it sets arbitrumGeoToken, owner, and rewarder
    assertEq(address(freshEscrow.arbitrumGeoToken()), arbitrumGeoToken);
    assertEq(freshEscrow.owner(), council);
    assertEq(freshEscrow.rewarder(), rewarderAddr);
  }

  function test_Initialize_WhenCalledTwice() external {
    // when called twice
    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    escrowProxy.initialize(
      IEscrow.EscrowInitializationParams({arbitrumGeoToken: arbitrumGeoToken, council: council, rewarder: rewarderAddr})
    );
  }

  // -------- pull --------
  function test_Pull_WhenCallerIsNotRewarder() external {
    // when caller is not rewarder
    // it reverts with OnlyRewarder
    vm.prank(alice);
    vm.expectRevert(IEscrow.OnlyRewarder.selector);
    escrowProxy.pull(alice, 1e18);
  }

  function test_Pull_WhenCalledByRewarder(uint256 _pullAmount) external {
    // when called by rewarder
    _pullAmount = bound(_pullAmount, 1, 1_000_000e18);

    // it transfers GEO from escrow to the recipient
    _mockAndExpect(arbitrumGeoToken, abi.encodeCall(IERC20.transfer, (alice, _pullAmount)), abi.encode(true));
    vm.prank(rewarderAddr);
    escrowProxy.pull(alice, _pullAmount);
  }

  // -------- typeId --------
  function test_TypeId_WhenCalled() external view {
    // when called

    // it returns the type
    assertEq(escrowProxy.typeId(), keccak256('ESCROW'));
  }

  // -------- name --------
  function test_Name_WhenCalled() external view {
    // when called

    // it returns the name
    assertEq(escrowProxy.name(), 'ESCROW');
  }

  // -------- version --------
  function test_Version_WhenCalled() external view {
    // when called

    // it returns semantic version
    assertEq(escrowProxy.version(), '1.0.0');
  }

  // -------- _authorizeUpgrade --------
  function test__authorizeUpgrade_WhenCalledByOwner() external {
    // when called by owner
    address newImplementation = address(new Escrow());
    vm.prank(council);
    // it authorizes the upgrade
    escrowProxy.upgradeToAndCall(newImplementation, '');
  }

  function test__authorizeUpgrade_WhenCalledByNon_owner(address _caller) external {
    // when called by non-owner
    _assumeFuzzable(_caller);
    vm.assume(_caller != council);
    address newImplementation = address(new Escrow());
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    escrowProxy.upgradeToAndCall(newImplementation, '');
  }
}
