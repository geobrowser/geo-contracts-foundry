// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Script} from 'forge-std/Script.sol';

import {Upgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {Escrow} from 'contracts/L2/Escrow.sol';
import {PaymentManager} from 'contracts/L2/PaymentManager.sol';
import {Rewarder} from 'contracts/L2/Rewarder.sol';
import {StakedGEOToken} from 'contracts/L2/StakedGEOToken.sol';
import {StakingManager} from 'contracts/L2/StakingManager.sol';
import {StakingRegistry} from 'contracts/L2/StakingRegistry.sol';
import {IEscrow} from 'interfaces/L2/IEscrow.sol';
import {IPaymentManager} from 'interfaces/L2/IPaymentManager.sol';
import {IRewarder} from 'interfaces/L2/IRewarder.sol';
import {IStakedGEOToken} from 'interfaces/L2/IStakedGEOToken.sol';
import {IStakingManager} from 'interfaces/L2/IStakingManager.sol';
import {IStakingRegistry} from 'interfaces/L2/IStakingRegistry.sol';

import 'script/Constants.sol' as Constants;

contract DeployL2Contracts is Script {
  uint256 public constant STAKING_REGISTRY_PROXY_DEPLOYMENT_OFFSET = 1;
  uint256 public constant STAKED_GEO_TOKEN_PROXY_DEPLOYMENT_OFFSET = 3;
  uint256 public constant STAKING_MANAGER_PROXY_DEPLOYMENT_OFFSET = 5;
  uint256 public constant REWARDER_PROXY_DEPLOYMENT_OFFSET = 7;
  uint256 public constant ESCROW_PROXY_DEPLOYMENT_OFFSET = 9;
  uint256 public constant PAYMENT_MANAGER_PROXY_DEPLOYMENT_OFFSET = 11;

  Escrow public escrowImplementation;
  PaymentManager public paymentManagerImplementation;
  Rewarder public rewarderImplementation;
  StakingRegistry public stakingRegistryImplementation;
  StakingManager public stakingManagerImplementation;
  StakedGEOToken public stakedGEOTokenImplementation;

  Escrow public escrowProxy;
  PaymentManager public paymentManagerProxy;
  Rewarder public rewarderProxy;
  StakingRegistry public stakingRegistryProxy;
  StakingManager public stakingManagerProxy;
  StakedGEOToken public stakedGEOTokenProxy;

  IEscrow.EscrowInitializationParams public escrowInitParams;
  IPaymentManager.PaymentManagerInitializationParams public paymentManagerInitParams;
  IRewarder.RewarderInitializationParams public rewarderInitParams;
  IStakingRegistry.StakingRegistryInitializationParams public stakingRegistryInitParams;
  IStakingManager.StakingManagerInitializationParams public stakingManagerInitParams;
  IStakedGEOToken.StakedGEOTokenInitializationParams public stakedGEOTokenInitParams;

  address internal _stakingRegistryProxyPrecomputedAddress;
  address internal _stakedGEOTokenProxyPrecomputedAddress;
  address internal _stakingManagerProxyPrecomputedAddress;
  address internal _rewarderProxyPrecomputedAddress;
  address internal _escrowProxyPrecomputedAddress;
  address internal _paymentManagerProxyPrecomputedAddress;

  error InvalidPrecomputedAddress();

  function run() public virtual {
    _setInitParams();

    vm.startBroadcast();

    stakingRegistryProxy = StakingRegistry(
      Upgrades.deployUUPSProxy(
        'StakingRegistry.sol:StakingRegistry', abi.encodeCall(StakingRegistry.initialize, (stakingRegistryInitParams))
      )
    );
    stakingRegistryImplementation = StakingRegistry(Upgrades.getImplementationAddress(address(stakingRegistryProxy)));

    stakedGEOTokenProxy = StakedGEOToken(
      Upgrades.deployUUPSProxy(
        'StakedGEOToken.sol:StakedGEOToken', abi.encodeCall(StakedGEOToken.initialize, (stakedGEOTokenInitParams))
      )
    );
    stakedGEOTokenImplementation = StakedGEOToken(Upgrades.getImplementationAddress(address(stakedGEOTokenProxy)));

    stakingManagerProxy = StakingManager(
      Upgrades.deployUUPSProxy(
        'StakingManager.sol:StakingManager', abi.encodeCall(StakingManager.initialize, (stakingManagerInitParams))
      )
    );
    stakingManagerImplementation = StakingManager(Upgrades.getImplementationAddress(address(stakingManagerProxy)));

    rewarderProxy = Rewarder(
      Upgrades.deployUUPSProxy('Rewarder.sol:Rewarder', abi.encodeCall(Rewarder.initialize, (rewarderInitParams)))
    );
    rewarderImplementation = Rewarder(Upgrades.getImplementationAddress(address(rewarderProxy)));

    escrowProxy =
      Escrow(Upgrades.deployUUPSProxy('Escrow.sol:Escrow', abi.encodeCall(Escrow.initialize, (escrowInitParams))));
    escrowImplementation = Escrow(Upgrades.getImplementationAddress(address(escrowProxy)));

    paymentManagerProxy = PaymentManager(
      Upgrades.deployUUPSProxy(
        'PaymentManager.sol:PaymentManager', abi.encodeCall(PaymentManager.initialize, (paymentManagerInitParams))
      )
    );
    paymentManagerImplementation = PaymentManager(Upgrades.getImplementationAddress(address(paymentManagerProxy)));

    if (
      address(stakingRegistryProxy) != _stakingRegistryProxyPrecomputedAddress
        || address(stakedGEOTokenProxy) != _stakedGEOTokenProxyPrecomputedAddress
        || address(stakingManagerProxy) != _stakingManagerProxyPrecomputedAddress
        || address(rewarderProxy) != _rewarderProxyPrecomputedAddress
        || address(escrowProxy) != _escrowProxyPrecomputedAddress
        || address(paymentManagerProxy) != _paymentManagerProxyPrecomputedAddress
    ) revert InvalidPrecomputedAddress();

    vm.stopBroadcast();
  }

  function _setInitParams() internal virtual {
    _stakingRegistryProxyPrecomputedAddress = _precomputeCreateAddress(STAKING_REGISTRY_PROXY_DEPLOYMENT_OFFSET);
    _stakedGEOTokenProxyPrecomputedAddress = _precomputeCreateAddress(STAKED_GEO_TOKEN_PROXY_DEPLOYMENT_OFFSET);
    _stakingManagerProxyPrecomputedAddress = _precomputeCreateAddress(STAKING_MANAGER_PROXY_DEPLOYMENT_OFFSET);
    _rewarderProxyPrecomputedAddress = _precomputeCreateAddress(REWARDER_PROXY_DEPLOYMENT_OFFSET);
    _escrowProxyPrecomputedAddress = _precomputeCreateAddress(ESCROW_PROXY_DEPLOYMENT_OFFSET);
    _paymentManagerProxyPrecomputedAddress = _precomputeCreateAddress(PAYMENT_MANAGER_PROXY_DEPLOYMENT_OFFSET);

    stakingRegistryInitParams =
      IStakingRegistry.StakingRegistryInitializationParams({council: Constants.ARBITRUM_ONE_GEO_MULTISIG_COUNCIL});
    stakedGEOTokenInitParams = IStakedGEOToken.StakedGEOTokenInitializationParams({
      council: Constants.ARBITRUM_ONE_GEO_MULTISIG_COUNCIL, stakingManager: _stakingManagerProxyPrecomputedAddress
    });
    stakingManagerInitParams = IStakingManager.StakingManagerInitializationParams({
      arbitrumGeoToken: Constants.ARBITRUM_ONE_GEO_TOKEN,
      council: Constants.ARBITRUM_ONE_GEO_MULTISIG_COUNCIL,
      stakingRegistry: _stakingRegistryProxyPrecomputedAddress,
      stakedGEOToken: _stakedGEOTokenProxyPrecomputedAddress,
      minAmount: Constants.ARBITRUM_ONE_STAKING_MANAGER_MIN_AMOUNT,
      unstakeRequestDelay: Constants.ARBITRUM_ONE_STAKING_MANAGER_UNSTAKE_REQUEST_DELAY
    });
    rewarderInitParams = IRewarder.RewarderInitializationParams({
      escrow: _escrowProxyPrecomputedAddress,
      paymentManager: _paymentManagerProxyPrecomputedAddress,
      council: Constants.ARBITRUM_ONE_GEO_MULTISIG_COUNCIL
    });
    escrowInitParams = IEscrow.EscrowInitializationParams({
      arbitrumGeoToken: Constants.ARBITRUM_ONE_GEO_TOKEN,
      council: Constants.ARBITRUM_ONE_GEO_MULTISIG_COUNCIL,
      rewarder: _rewarderProxyPrecomputedAddress
    });
    paymentManagerInitParams = IPaymentManager.PaymentManagerInitializationParams({
      arbitrumGeoToken: Constants.ARBITRUM_ONE_GEO_TOKEN,
      outbox: Constants.ARBITRUM_ONE_OUTBOX,
      rewarder: _rewarderProxyPrecomputedAddress,
      escrow: _escrowProxyPrecomputedAddress,
      spaceRegistry: Constants.GEO_SPACE_REGISTRY,
      council: Constants.ARBITRUM_ONE_GEO_MULTISIG_COUNCIL,
      paymentRequestDelay: Constants.ARBITRUM_ONE_PAYMENT_MANAGER_PAYMENT_REQUEST_DELAY
    });
  }

  function _precomputeCreateAddress(uint256 _deploymentOffset) internal view returns (address _targetAddress) {
    uint256 _targetNonce = vm.getNonce(tx.origin) + _deploymentOffset;
    _targetAddress = vm.computeCreateAddress(tx.origin, _targetNonce);
  }
}
