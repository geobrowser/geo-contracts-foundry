// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

// Ethereum mainnet
address constant ETHEREUM_MAINNET_GEO_MULTISIG_COUNCIL = address(0x100);
address constant ETHEREUM_MAINNET_INITIAL_SUPPLY_RECIPIENT = address(0x101);
uint256 constant ETHEREUM_MAINNET_GEO_TOKEN_INITIAL_SUPPLY = 10_000_000_000e18; // 10B

// Arbitrum One
address constant ARBITRUM_ONE_GEO_MULTISIG_COUNCIL = address(0x200);
address constant ARBITRUM_ONE_OUTBOX = address(0x201);
/// @dev WETH on Arbitrum One — integration/fork stand-in for bridged GEO until real token deployed
address constant ARBITRUM_ONE_GEO_TOKEN = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
uint256 constant ARBITRUM_ONE_STAKING_MANAGER_MIN_AMOUNT = 1e18;
uint256 constant ARBITRUM_ONE_STAKING_MANAGER_UNSTAKE_REQUEST_DELAY = 7 days;
uint256 constant ARBITRUM_ONE_PAYMENT_MANAGER_PAYMENT_REQUEST_DELAY = 7 days;

// Geo (L3)
address constant GEO_GEO_MULTISIG_COUNCIL = address(0x300);
address constant GEO_SPACE_REGISTRY = address(0x301);
