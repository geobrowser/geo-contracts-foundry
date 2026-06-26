// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {
  ERC20PermitUpgradeable
} from '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol';
import {IERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol';

import {IGEOToken} from 'interfaces/L1/IGEOToken.sol';

/**
 * @title GEO Token
 * @notice Implementation of the GEO token with ERC20, ERC20Permit, and UUPS upgradeability
 * @custom:security WARNING: This contract has not been audited, and may contain bugs.
 */
contract GEOToken is ERC20PermitUpgradeable, OwnableUpgradeable, UUPSUpgradeable, IGEOToken {
  /**
   * @notice ERC-7201 namespaced storage slot for the GEOToken contract
   * @custom:storage-location erc7201:geo.storage.GEOToken
   * @dev Computed with: keccak256(abi.encode(uint256(keccak256("geo.storage.GEOToken")) - 1)) & ~bytes32(uint256(0xff))
   */
  bytes32 internal constant _GEO_TOKEN_STORAGE_LOCATION =
    0x247bc561aefbadbbd8afbceb11087bd61a1c2c9df4396a77ca130d824ed7bb00;

  /**
   * @notice checks that the caller is the minter
   * @dev Reverts if caller is not the minter.
   */
  modifier onlyMinter() virtual {
    if (msg.sender != _getGEOTokenStorage().minter) revert OnlyMinter();
    _;
  }

  /**
   * @notice constructor
   * @custom:oz-upgrades-unsafe-allow constructor
   */
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IGEOToken
  function initialize(GEOTokenInitializationParams calldata _initParams) external virtual initializer {
    if (_initParams.initialSupplyRecipient == address(0)) {
      revert InvalidAddress();
    }

    __ERC20_init('GEO Token', 'GEO');
    __ERC20Permit_init('GEO Token');
    __Ownable_init(_initParams.council);
    __UUPSUpgradeable_init();

    _setMinter(_initParams.minter);

    _mint(_initParams.initialSupplyRecipient, _initParams.initialSupply);
  }

  /// @inheritdoc IGEOToken
  function mint(address _to, uint256 _amount) external virtual onlyMinter {
    if (_amount == 0) revert ZeroAmount();
    _mint(_to, _amount);
  }

  /// @inheritdoc IGEOToken
  function burn(uint256 _amount) external virtual {
    if (_amount == 0) revert ZeroAmount();
    _burn(msg.sender, _amount);
  }

  /// @inheritdoc IGEOToken
  function setMinter(address _minter) external virtual onlyOwner {
    _setMinter(_minter);
  }

  /// @inheritdoc IGEOToken
  function minter() public view returns (address _minter) {
    _minter = _getGEOTokenStorage().minter;
  }

  /// @inheritdoc ERC20PermitUpgradeable
  function nonces(address _owner) public view virtual override(IERC20Permit, ERC20PermitUpgradeable) returns (uint256) {
    return super.nonces(_owner);
  }

  /// @inheritdoc IGEOToken
  function typeId() public pure virtual returns (bytes32 _typeId) {
    _typeId = keccak256(bytes('GEO_TOKEN'));
  }

  /// @inheritdoc IGEOToken
  function version() public pure virtual returns (string memory _version) {
    _version = '1.0.0';
  }

  /**
   * @notice Sets the minter address
   * @param _minter The new minter address
   * @dev Reverts with `InvalidAddress` when `_minter` is zero
   */
  function _setMinter(address _minter) internal virtual {
    if (_minter == address(0)) revert InvalidAddress();
    _getGEOTokenStorage().minter = _minter;
    emit MinterSet(_minter);
  }

  /**
   * @inheritdoc UUPSUpgradeable
   * @dev Function that should revert when msg.sender is not authorized to upgrade the contract
   */
  function _authorizeUpgrade(
    address /* _newImplementation */
  ) internal virtual override onlyOwner {}

  /**
   * @notice Returns the ERC-7201 namespaced storage pointer for GEOToken
   * @return $_ Namespaced storage for GEOToken
   * @custom:storage-location erc7201:geo.storage.GEOToken
   */
  function _getGEOTokenStorage() internal pure returns (GEOTokenStorage storage $_) {
    assembly {
      $_.slot := _GEO_TOKEN_STORAGE_LOCATION
    }
  }
}
