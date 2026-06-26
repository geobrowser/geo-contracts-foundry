// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';
import {Test} from 'forge-std/Test.sol';

import {StakedGEOToken} from 'contracts/L2/StakedGEOToken.sol';
import {StakingManager} from 'contracts/L2/StakingManager.sol';
import {StakingRegistry} from 'contracts/L2/StakingRegistry.sol';
import {IStakedGEOToken} from 'interfaces/L2/IStakedGEOToken.sol';
import {IStakingManager} from 'interfaces/L2/IStakingManager.sol';
import {IStakingRegistry} from 'interfaces/L2/IStakingRegistry.sol';

import {HandlerStakingManager} from 'test/invariants/L2/fuzz/handlers/HandlerStakingManager.t.sol';
import {HandlerStakingRegistry} from 'test/invariants/L2/fuzz/handlers/HandlerStakingRegistry.t.sol';
import {L2HandlerBlockchain} from 'test/invariants/L2/fuzz/handlers/L2HandlerBlockchain.t.sol';
import {InvariantGEOToken} from 'test/invariants/L2/helpers/InvariantGEOToken.sol';

/// @notice Shared deployment and handler wiring for StakingManager invariant tests
abstract contract L2Setup is Test {
  uint256 internal constant _NUM_STAKERS = 3;
  uint256 internal constant _PRIMARY_STAKER_INDEX = 0;
  uint256 internal constant _SECONDARY_STAKER_INDEX = 1;
  uint256 internal constant _INVARIANT_MIN_AMOUNT = 1e18;
  /// @dev Shorter than production delay so `handler_unstake` can execute within bounded warps
  uint256 internal constant _INVARIANT_UNSTAKE_REQUEST_DELAY = 1 days;
  /// @dev Manager proxy CREATE nonce offset after `geoToken` and two UUPS proxy pairs
  uint256 internal constant _STAKING_MANAGER_PROXY_DEPLOYMENT_OFFSET = 5;

  InvariantGEOToken public geoToken;
  StakingRegistry public stakingRegistryProxy;
  StakedGEOToken public stakedGEOTokenProxy;
  StakingManager public stakingManagerProxy;

  address public council;
  address[] public stakers;

  L2HandlerBlockchain public handlerBlockchain;
  HandlerStakingRegistry public handlerStakingRegistry;
  HandlerStakingManager public handlerStakingManager;

  function setUp() public virtual {
    council = makeAddr('invariant_council');
    _createStakers();
    _deployContracts();
    _configureTargets();
  }

  function _createStakers() internal {
    stakers = new address[](_NUM_STAKERS);
    for (uint256 _i = 0; _i < _NUM_STAKERS; _i++) {
      stakers[_i] = makeAddr(string.concat('invariant_staker', vm.toString(_i)));
    }
  }

  function _deployContracts() internal {
    geoToken = new InvariantGEOToken();

    address _stakingManagerProxyAddress = _precomputeCreateAddress(_STAKING_MANAGER_PROXY_DEPLOYMENT_OFFSET);

    StakingRegistry _stakingRegistryImplementation = new StakingRegistry();
    stakingRegistryProxy = StakingRegistry(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(_stakingRegistryImplementation),
          abi.encodeCall(
            StakingRegistry.initialize, (IStakingRegistry.StakingRegistryInitializationParams({council: council}))
          )
        ))
    );

    StakedGEOToken _stakedGEOTokenImplementation = new StakedGEOToken();
    stakedGEOTokenProxy = StakedGEOToken(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(_stakedGEOTokenImplementation),
          abi.encodeCall(
            StakedGEOToken.initialize,
            (IStakedGEOToken.StakedGEOTokenInitializationParams({
                council: council, stakingManager: _stakingManagerProxyAddress
              }))
          )
        ))
    );

    StakingManager _stakingManagerImplementation = new StakingManager();
    stakingManagerProxy = StakingManager(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(_stakingManagerImplementation),
          abi.encodeCall(
            StakingManager.initialize,
            (IStakingManager.StakingManagerInitializationParams({
                arbitrumGeoToken: address(geoToken),
                council: council,
                stakingRegistry: address(stakingRegistryProxy),
                stakedGEOToken: address(stakedGEOTokenProxy),
                minAmount: _INVARIANT_MIN_AMOUNT,
                unstakeRequestDelay: _INVARIANT_UNSTAKE_REQUEST_DELAY
              }))
          )
        ))
    );
    assertEq(address(stakingManagerProxy), _stakingManagerProxyAddress);
  }

  function _configureTargets() internal {
    for (uint256 _i = 0; _i < stakers.length; _i++) {
      targetSender(stakers[_i]);
    }

    handlerBlockchain = new L2HandlerBlockchain();
    handlerStakingRegistry =
      new HandlerStakingRegistry(stakingManagerProxy, stakingRegistryProxy, geoToken, council, stakers);
    handlerStakingManager = new HandlerStakingManager(
      stakingManagerProxy, stakingRegistryProxy, geoToken, council, stakers, handlerStakingRegistry
    );

    targetContract(address(handlerBlockchain));
    targetContract(address(handlerStakingRegistry));
    targetContract(address(handlerStakingManager));
  }

  function _precomputeCreateAddress(uint256 _deploymentOffset) internal view returns (address _targetAddress) {
    uint256 _targetNonce = vm.getNonce(address(this)) + _deploymentOffset;
    _targetAddress = vm.computeCreateAddress(address(this), _targetNonce);
  }
}
