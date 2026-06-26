// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title IEscrow
 * @notice Escrow holding GEO incentives supply; council funds it via ERC20 transfer; only the authorized rewarder may pull
 */
interface IEscrow is ISemver {
  /**
   * @notice ERC-7201 namespaced storage for Escrow.
   * @param arbitrumGeoToken The bridged GEO ERC-20 on Arbitrum held in custody
   * @param rewarder The Rewarder contract authorized to pull GEO
   * @custom:storage-location erc7201:geo.storage.Escrow
   */
  struct EscrowStorage {
    IERC20 arbitrumGeoToken;
    address rewarder;
  }

  /**
   * @notice Parameters required for initializing the Escrow contract
   * @param arbitrumGeoToken Address of the GEO ERC-20 on Arbitrum held in custody
   * @param council Address of the council (owner)
   * @param rewarder Authorized rewarder contract (must be non-zero)
   */
  struct EscrowInitializationParams {
    address arbitrumGeoToken;
    address council;
    address rewarder;
  }

  /// @notice Thrown when caller is not the authorized rewarder
  error OnlyRewarder();

  /// @notice Thrown when the provided address is invalid
  error InvalidAddress();

  /**
   * @notice Initializes the Escrow contract behind a UUPS proxy
   * @dev Can only be called once during proxy deployment.
   * @param _initParams Arbitrum GEO token, council (owner), and rewarder (both token and rewarder must be non-zero)
   * @custom:reverts InvalidAddress when `arbitrumGeoToken` or `rewarder` is zero
   */
  function initialize(EscrowInitializationParams calldata _initParams) external;

  /**
   * @notice Transfers GEO from escrow to a recipient
   * @param _to The recipient address
   * @param _amount The amount to transfer
   * @custom:reverts OnlyRewarder when `msg.sender` is not `rewarder`
   */
  function pull(address _to, uint256 _amount) external;

  /**
   * @notice Returns the bridged GEO ERC-20 on Arbitrum held in escrow
   * @return _arbitrumGeoToken The Arbitrum GEO ERC-20
   */
  function arbitrumGeoToken() external view returns (IERC20 _arbitrumGeoToken);

  /**
   * @notice Returns the rewarder authorized to pull GEO from escrow
   * @return _rewarder The Rewarder contract address
   */
  function rewarder() external view returns (address _rewarder);
}
