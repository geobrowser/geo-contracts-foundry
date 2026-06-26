// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {IEscrow} from 'interfaces/L2/IEscrow.sol';
import {IPaymentManager} from 'interfaces/L2/IPaymentManager.sol';
import {IRewarder} from 'interfaces/L2/IRewarder.sol';
import {IStakedGEOToken} from 'interfaces/L2/IStakedGEOToken.sol';
import {IStakingManager} from 'interfaces/L2/IStakingManager.sol';
import {IStakingRegistry} from 'interfaces/L2/IStakingRegistry.sol';
import {DeployL2Contracts} from 'script/L2/DeployL2Contracts.s.sol';

/**
 * @title MockDeployL2Contracts
 * @notice Mock contract for testing DeployL2Contracts with additional test helper functions.
 * @dev Workarounds are re-applied after _setInitParams so "wrong address" tests can force a mismatch.
 */
contract MockDeployL2Contracts is DeployL2Contracts {
  address internal _workaroundStakingRegistryProxyPrecomputedAddress;
  address internal _workaroundStakedGEOTokenProxyPrecomputedAddress;
  address internal _workaroundStakingManagerProxyPrecomputedAddress;
  address internal _workaroundRewarderProxyPrecomputedAddress;
  address internal _workaroundEscrowProxyPrecomputedAddress;
  address internal _workaroundPaymentManagerProxyPrecomputedAddress;

  function workaround_setStakingRegistryProxyPrecomputedAddress(address __stakingRegistryProxyPrecomputedAddress)
    external
  {
    _workaroundStakingRegistryProxyPrecomputedAddress = __stakingRegistryProxyPrecomputedAddress;
  }

  function workaround_setStakedGEOTokenProxyPrecomputedAddress(address __stakedGEOTokenProxyPrecomputedAddress)
    external
  {
    _workaroundStakedGEOTokenProxyPrecomputedAddress = __stakedGEOTokenProxyPrecomputedAddress;
  }

  function workaround_setStakingManagerProxyPrecomputedAddress(address __stakingManagerProxyPrecomputedAddress)
    external
  {
    _workaroundStakingManagerProxyPrecomputedAddress = __stakingManagerProxyPrecomputedAddress;
  }

  function workaround_setRewarderProxyPrecomputedAddress(address __rewarderProxyPrecomputedAddress) external {
    _workaroundRewarderProxyPrecomputedAddress = __rewarderProxyPrecomputedAddress;
  }

  function workaround_setEscrowProxyPrecomputedAddress(address __escrowProxyPrecomputedAddress) external {
    _workaroundEscrowProxyPrecomputedAddress = __escrowProxyPrecomputedAddress;
  }

  function workaround_setPaymentManagerProxyPrecomputedAddress(address __paymentManagerProxyPrecomputedAddress)
    external
  {
    _workaroundPaymentManagerProxyPrecomputedAddress = __paymentManagerProxyPrecomputedAddress;
  }

  function _setInitParams() internal override {
    super._setInitParams();
    if (_workaroundStakingRegistryProxyPrecomputedAddress != address(0)) {
      _stakingRegistryProxyPrecomputedAddress = _workaroundStakingRegistryProxyPrecomputedAddress;
    }
    if (_workaroundStakedGEOTokenProxyPrecomputedAddress != address(0)) {
      _stakedGEOTokenProxyPrecomputedAddress = _workaroundStakedGEOTokenProxyPrecomputedAddress;
    }
    if (_workaroundStakingManagerProxyPrecomputedAddress != address(0)) {
      _stakingManagerProxyPrecomputedAddress = _workaroundStakingManagerProxyPrecomputedAddress;
    }
    if (_workaroundRewarderProxyPrecomputedAddress != address(0)) {
      _rewarderProxyPrecomputedAddress = _workaroundRewarderProxyPrecomputedAddress;
    }
    if (_workaroundEscrowProxyPrecomputedAddress != address(0)) {
      _escrowProxyPrecomputedAddress = _workaroundEscrowProxyPrecomputedAddress;
    }
    if (_workaroundPaymentManagerProxyPrecomputedAddress != address(0)) {
      _paymentManagerProxyPrecomputedAddress = _workaroundPaymentManagerProxyPrecomputedAddress;
    }
  }

  function exposed_initParams()
    external
    view
    returns (
      IEscrow.EscrowInitializationParams memory _escrowInitParams,
      IPaymentManager.PaymentManagerInitializationParams memory _paymentManagerInitParams,
      IRewarder.RewarderInitializationParams memory _rewarderInitParams,
      IStakingRegistry.StakingRegistryInitializationParams memory _stakingRegistryInitParams,
      IStakingManager.StakingManagerInitializationParams memory _stakingManagerInitParams,
      IStakedGEOToken.StakedGEOTokenInitializationParams memory _stakedGEOTokenInitParams
    )
  {
    _escrowInitParams = escrowInitParams;
    _paymentManagerInitParams = paymentManagerInitParams;
    _rewarderInitParams = rewarderInitParams;
    _stakingRegistryInitParams = stakingRegistryInitParams;
    _stakingManagerInitParams = stakingManagerInitParams;
    _stakedGEOTokenInitParams = stakedGEOTokenInitParams;
  }
}
