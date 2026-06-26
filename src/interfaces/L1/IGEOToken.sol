// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {IERC5267} from '@openzeppelin/contracts/interfaces/IERC5267.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol';

/**
 * @title IGEOToken
 * @notice Interface for the GEO token contract
 */
interface IGEOToken is IERC20Metadata, IERC20Permit, IERC5267 {
  /**
   * @notice ERC-7201 namespaced storage for GEOToken.
   * @param minter The address authorized to mint new tokens (ERC20 state remains in OpenZeppelin slots).
   * @custom:storage-location erc7201:geo.storage.GEOToken
   */
  struct GEOTokenStorage {
    address minter;
  }

  /**
   * @notice Struct used to initialize the GEO token contract.
   * @dev This struct is passed to the initializer.
   * @param council The address of the GEO multisig council.
   * @param minter The address allowed to mint new tokens.
   * @param initialSupplyRecipient The address that receives the initial GEO token supply.
   * @param initialSupply The amount of GEO tokens minted to the initial supply recipient.
   */
  struct GEOTokenInitializationParams {
    address council;
    address minter;
    address initialSupplyRecipient;
    uint256 initialSupply;
  }

  /**
   * @notice Emitted when the minter address is set.
   * @param _minter The new minter address.
   */
  event MinterSet(address _minter);

  /// @notice Thrown when the caller is not the minter.
  error OnlyMinter();

  /// @notice Thrown when the provided address is invalid.
  error InvalidAddress();

  /// @notice Thrown when a zero token amount is invalid.
  error ZeroAmount();

  /**
   * @notice Initializes the GEO token contract.
   * @dev Can only be called once during proxy deployment.
   * @param _initParams The initialization parameters.
   * @custom:reverts InvalidAddress when `initialSupplyRecipient` or `minter` is zero
   */
  function initialize(GEOTokenInitializationParams calldata _initParams) external;

  /**
   * @notice Mints new tokens to the specified address.
   * @dev Callable only by the minter.
   * @param _to The address that will receive the minted tokens.
   * @param _amount The amount of tokens to mint.
   * @custom:reverts ZeroAmount when `_amount == 0`
   */
  function mint(address _to, uint256 _amount) external;

  /**
   * @notice Burns tokens from the caller's balance.
   * @param _amount The amount of tokens to burn.
   * @custom:reverts ZeroAmount when `_amount == 0`
   */
  function burn(uint256 _amount) external;

  /**
   * @notice Sets the minter to a new address.
   * @dev Callable only by the owner (council).
   * @param _minter The new minter address.
   * @custom:reverts InvalidAddress when `_minter == address(0)`
   */
  function setMinter(address _minter) external;

  /**
   * @notice Returns the address authorized to mint new $GEO tokens.
   * @return _minter The address with minting rights.
   */
  function minter() external view returns (address _minter);

  /**
   * @notice Returns the semantic type identifier of the contract
   * @return _typeId The type identifier (`keccak256(bytes('GEO_TOKEN'))`)
   */
  function typeId() external pure returns (bytes32 _typeId);

  /**
   * @notice Returns the semantic version of the contract
   * @return _version The semantic version string
   */
  function version() external pure returns (string memory _version);
}
