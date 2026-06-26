// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {TestHelper} from 'unit-helpers/TestHelper.sol';

import {ERC1967Utils} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol';

import {IEscrow} from 'interfaces/L2/IEscrow.sol';
import {IPaymentManager} from 'interfaces/L2/IPaymentManager.sol';
import {IRewarder} from 'interfaces/L2/IRewarder.sol';
import {IStakedGEOToken} from 'interfaces/L2/IStakedGEOToken.sol';
import {IStakingManager} from 'interfaces/L2/IStakingManager.sol';
import {IStakingRegistry} from 'interfaces/L2/IStakingRegistry.sol';
import {DeployL2Contracts} from 'script/L2/DeployL2Contracts.s.sol';
import {MockDeployL2Contracts} from 'test/unit/L2/mocks/MockDeployL2Contracts.sol';

import 'script/Constants.sol' as Constants;

contract UnitDeployL2Contractsrun is TestHelper {
  MockDeployL2Contracts public deployL2Contracts;

  function setUp() external {
    deployL2Contracts = new MockDeployL2Contracts();
  }

  modifier whenInitializationParametersAreSetUp() {
    _;
  }

  function test_WhenPrecomputedAddressesAreCorrect() public whenInitializationParametersAreSetUp {
    (
      address _stakingRegistryProxyAddress,
      address _stakedGEOTokenProxyAddress,
      address _stakingManagerProxyAddress,
      address _rewarderProxyAddress,
      address _escrowProxyAddress,
      address _paymentManagerProxyAddress
    ) = _precomputeProxyAddresses();

    deployL2Contracts.run();

    (
      IEscrow.EscrowInitializationParams memory _escrowInitParams,
      IPaymentManager.PaymentManagerInitializationParams memory _paymentManagerInitParams,
      IRewarder.RewarderInitializationParams memory _rewarderInitParams,
      IStakingRegistry.StakingRegistryInitializationParams memory _stakingRegistryInitParams,
      IStakingManager.StakingManagerInitializationParams memory _stakingManagerInitParams,
      IStakedGEOToken.StakedGEOTokenInitializationParams memory _stakedGEOTokenInitParams
    ) = deployL2Contracts.exposed_initParams();

    assertEq(_stakingRegistryInitParams.council, Constants.ARBITRUM_ONE_GEO_MULTISIG_COUNCIL);
    assertEq(_stakingManagerInitParams.arbitrumGeoToken, Constants.ARBITRUM_ONE_GEO_TOKEN);
    assertEq(_stakingManagerInitParams.council, Constants.ARBITRUM_ONE_GEO_MULTISIG_COUNCIL);
    assertEq(_stakingManagerInitParams.stakingRegistry, _stakingRegistryProxyAddress);
    assertEq(_stakingManagerInitParams.stakedGEOToken, _stakedGEOTokenProxyAddress);
    assertEq(_stakingManagerInitParams.minAmount, Constants.ARBITRUM_ONE_STAKING_MANAGER_MIN_AMOUNT);
    assertEq(
      _stakingManagerInitParams.unstakeRequestDelay, Constants.ARBITRUM_ONE_STAKING_MANAGER_UNSTAKE_REQUEST_DELAY
    );
    assertEq(_stakedGEOTokenInitParams.council, Constants.ARBITRUM_ONE_GEO_MULTISIG_COUNCIL);
    assertEq(_stakedGEOTokenInitParams.stakingManager, _stakingManagerProxyAddress);
    assertEq(_rewarderInitParams.escrow, _escrowProxyAddress);
    assertEq(_rewarderInitParams.paymentManager, _paymentManagerProxyAddress);
    assertEq(_rewarderInitParams.council, Constants.ARBITRUM_ONE_GEO_MULTISIG_COUNCIL);
    assertEq(_escrowInitParams.arbitrumGeoToken, Constants.ARBITRUM_ONE_GEO_TOKEN);
    assertEq(_escrowInitParams.council, Constants.ARBITRUM_ONE_GEO_MULTISIG_COUNCIL);
    assertEq(_escrowInitParams.rewarder, _rewarderProxyAddress);
    assertEq(_paymentManagerInitParams.arbitrumGeoToken, Constants.ARBITRUM_ONE_GEO_TOKEN);
    assertEq(_paymentManagerInitParams.outbox, Constants.ARBITRUM_ONE_OUTBOX);
    assertEq(_paymentManagerInitParams.rewarder, _rewarderProxyAddress);
    assertEq(_paymentManagerInitParams.escrow, _escrowProxyAddress);
    assertEq(_paymentManagerInitParams.spaceRegistry, Constants.GEO_SPACE_REGISTRY);
    assertEq(_paymentManagerInitParams.council, Constants.ARBITRUM_ONE_GEO_MULTISIG_COUNCIL);
    assertEq(
      _paymentManagerInitParams.paymentRequestDelay, Constants.ARBITRUM_ONE_PAYMENT_MANAGER_PAYMENT_REQUEST_DELAY
    );

    assertEq(deployL2Contracts.escrowImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    assertEq(deployL2Contracts.paymentManagerImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    assertEq(deployL2Contracts.rewarderImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    assertEq(deployL2Contracts.stakingRegistryImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    assertEq(deployL2Contracts.stakedGEOTokenImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    assertEq(deployL2Contracts.stakingManagerImplementation().proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);

    assertEq(address(deployL2Contracts.stakingRegistryProxy()), _stakingRegistryProxyAddress);
    assertEq(address(deployL2Contracts.stakedGEOTokenProxy()), _stakedGEOTokenProxyAddress);
    assertEq(address(deployL2Contracts.stakingManagerProxy()), _stakingManagerProxyAddress);
    assertEq(address(deployL2Contracts.rewarderProxy()), _rewarderProxyAddress);
    assertEq(address(deployL2Contracts.escrowProxy()), _escrowProxyAddress);
    assertEq(address(deployL2Contracts.paymentManagerProxy()), _paymentManagerProxyAddress);

    assertEq(
      address(
        uint160(uint256(vm.load(address(deployL2Contracts.stakingRegistryProxy()), ERC1967Utils.IMPLEMENTATION_SLOT)))
      ),
      address(deployL2Contracts.stakingRegistryImplementation())
    );
    assertEq(deployL2Contracts.stakingRegistryProxy().owner(), _stakingRegistryInitParams.council);

    assertEq(
      address(
        uint160(uint256(vm.load(address(deployL2Contracts.stakedGEOTokenProxy()), ERC1967Utils.IMPLEMENTATION_SLOT)))
      ),
      address(deployL2Contracts.stakedGEOTokenImplementation())
    );
    assertEq(deployL2Contracts.stakedGEOTokenProxy().owner(), _stakedGEOTokenInitParams.council);
    assertEq(deployL2Contracts.stakedGEOTokenProxy().stakingManager(), _stakedGEOTokenInitParams.stakingManager);

    assertEq(
      address(
        uint160(uint256(vm.load(address(deployL2Contracts.stakingManagerProxy()), ERC1967Utils.IMPLEMENTATION_SLOT)))
      ),
      address(deployL2Contracts.stakingManagerImplementation())
    );
    assertEq(
      address(deployL2Contracts.stakingManagerProxy().arbitrumGeoToken()), _stakingManagerInitParams.arbitrumGeoToken
    );
    assertEq(deployL2Contracts.stakingManagerProxy().owner(), _stakingManagerInitParams.council);
    assertEq(
      address(deployL2Contracts.stakingManagerProxy().stakingRegistry()), _stakingManagerInitParams.stakingRegistry
    );
    assertEq(
      address(deployL2Contracts.stakingManagerProxy().stakedGEOToken()), _stakingManagerInitParams.stakedGEOToken
    );
    assertEq(deployL2Contracts.stakingManagerProxy().minAmount(), _stakingManagerInitParams.minAmount);
    assertEq(
      deployL2Contracts.stakingManagerProxy().unstakeRequestDelay(), _stakingManagerInitParams.unstakeRequestDelay
    );

    assertEq(
      address(uint160(uint256(vm.load(address(deployL2Contracts.rewarderProxy()), ERC1967Utils.IMPLEMENTATION_SLOT)))),
      address(deployL2Contracts.rewarderImplementation())
    );
    assertEq(address(deployL2Contracts.rewarderProxy().escrow()), _rewarderInitParams.escrow);
    assertEq(address(deployL2Contracts.rewarderProxy().paymentManager()), _rewarderInitParams.paymentManager);
    assertEq(deployL2Contracts.rewarderProxy().owner(), _rewarderInitParams.council);

    assertEq(
      address(uint160(uint256(vm.load(address(deployL2Contracts.escrowProxy()), ERC1967Utils.IMPLEMENTATION_SLOT)))),
      address(deployL2Contracts.escrowImplementation())
    );
    assertEq(address(deployL2Contracts.escrowProxy().arbitrumGeoToken()), _escrowInitParams.arbitrumGeoToken);
    assertEq(deployL2Contracts.escrowProxy().rewarder(), _escrowInitParams.rewarder);
    assertEq(deployL2Contracts.escrowProxy().owner(), _escrowInitParams.council);

    assertEq(
      address(
        uint160(uint256(vm.load(address(deployL2Contracts.paymentManagerProxy()), ERC1967Utils.IMPLEMENTATION_SLOT)))
      ),
      address(deployL2Contracts.paymentManagerImplementation())
    );
    assertEq(
      address(deployL2Contracts.paymentManagerProxy().arbitrumGeoToken()), _paymentManagerInitParams.arbitrumGeoToken
    );
    assertEq(address(deployL2Contracts.paymentManagerProxy().outbox()), _paymentManagerInitParams.outbox);
    assertEq(deployL2Contracts.paymentManagerProxy().rewarder(), _paymentManagerInitParams.rewarder);
    assertEq(deployL2Contracts.paymentManagerProxy().escrow(), _paymentManagerInitParams.escrow);
    assertEq(deployL2Contracts.paymentManagerProxy().spaceRegistry(), _paymentManagerInitParams.spaceRegistry);
    assertEq(deployL2Contracts.paymentManagerProxy().owner(), _paymentManagerInitParams.council);
    assertEq(
      deployL2Contracts.paymentManagerProxy().paymentRequestDelay(), _paymentManagerInitParams.paymentRequestDelay
    );
  }

  function test_WhenStakingRegistryProxyPrecomputedAddressIsIncorrect() public whenInitializationParametersAreSetUp {
    deployL2Contracts.workaround_setStakingRegistryProxyPrecomputedAddress(makeAddr('wrongStakingRegistry'));

    vm.expectRevert(DeployL2Contracts.InvalidPrecomputedAddress.selector);
    deployL2Contracts.run();
  }

  function test_WhenStakedGEOTokenProxyPrecomputedAddressIsIncorrect() public whenInitializationParametersAreSetUp {
    deployL2Contracts.workaround_setStakedGEOTokenProxyPrecomputedAddress(makeAddr('wrongStakedGEOToken'));

    vm.expectRevert(DeployL2Contracts.InvalidPrecomputedAddress.selector);
    deployL2Contracts.run();
  }

  function test_WhenStakingManagerProxyPrecomputedAddressIsIncorrect() public whenInitializationParametersAreSetUp {
    deployL2Contracts.workaround_setStakingManagerProxyPrecomputedAddress(makeAddr('wrongStakingManager'));

    vm.expectRevert(DeployL2Contracts.InvalidPrecomputedAddress.selector);
    deployL2Contracts.run();
  }

  function test_WhenRewarderProxyPrecomputedAddressIsIncorrect() public whenInitializationParametersAreSetUp {
    deployL2Contracts.workaround_setRewarderProxyPrecomputedAddress(makeAddr('wrongRewarder'));

    vm.expectRevert(DeployL2Contracts.InvalidPrecomputedAddress.selector);
    deployL2Contracts.run();
  }

  function test_WhenEscrowProxyPrecomputedAddressIsIncorrect() public whenInitializationParametersAreSetUp {
    deployL2Contracts.workaround_setEscrowProxyPrecomputedAddress(makeAddr('wrongEscrow'));

    vm.expectRevert(DeployL2Contracts.InvalidPrecomputedAddress.selector);
    deployL2Contracts.run();
  }

  function test_WhenPaymentManagerProxyPrecomputedAddressIsIncorrect() public whenInitializationParametersAreSetUp {
    deployL2Contracts.workaround_setPaymentManagerProxyPrecomputedAddress(makeAddr('wrongPaymentManager'));

    vm.expectRevert(DeployL2Contracts.InvalidPrecomputedAddress.selector);
    deployL2Contracts.run();
  }

  function _precomputeProxyAddresses()
    internal
    view
    returns (
      address _stakingRegistryProxyAddress,
      address _stakedGEOTokenProxyAddress,
      address _stakingManagerProxyAddress,
      address _rewarderProxyAddress,
      address _escrowProxyAddress,
      address _paymentManagerProxyAddress
    )
  {
    uint256 _originNonce = vm.getNonce(tx.origin);
    uint256 _stakingRegistryProxyNonce = _originNonce + deployL2Contracts.STAKING_REGISTRY_PROXY_DEPLOYMENT_OFFSET();
    uint256 _stakedGEOTokenProxyNonce = _originNonce + deployL2Contracts.STAKED_GEO_TOKEN_PROXY_DEPLOYMENT_OFFSET();
    uint256 _stakingManagerProxyNonce = _originNonce + deployL2Contracts.STAKING_MANAGER_PROXY_DEPLOYMENT_OFFSET();
    uint256 _rewarderProxyNonce = _originNonce + deployL2Contracts.REWARDER_PROXY_DEPLOYMENT_OFFSET();
    uint256 _escrowProxyNonce = _originNonce + deployL2Contracts.ESCROW_PROXY_DEPLOYMENT_OFFSET();
    uint256 _paymentManagerProxyNonce = _originNonce + deployL2Contracts.PAYMENT_MANAGER_PROXY_DEPLOYMENT_OFFSET();

    _stakingRegistryProxyAddress = vm.computeCreateAddress(tx.origin, _stakingRegistryProxyNonce);
    _stakedGEOTokenProxyAddress = vm.computeCreateAddress(tx.origin, _stakedGEOTokenProxyNonce);
    _stakingManagerProxyAddress = vm.computeCreateAddress(tx.origin, _stakingManagerProxyNonce);
    _rewarderProxyAddress = vm.computeCreateAddress(tx.origin, _rewarderProxyNonce);
    _escrowProxyAddress = vm.computeCreateAddress(tx.origin, _escrowProxyNonce);
    _paymentManagerProxyAddress = vm.computeCreateAddress(tx.origin, _paymentManagerProxyNonce);
  }
}
