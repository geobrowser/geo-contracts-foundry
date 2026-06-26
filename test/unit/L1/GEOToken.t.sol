// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC20Errors} from '@openzeppelin/contracts/interfaces/draft-IERC6093.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';
import {GEOToken} from 'contracts/L1/GEOToken.sol';
import {IGEOToken} from 'interfaces/L1/IGEOToken.sol';
import {MockGEOToken} from 'test/unit/L1/mocks/MockGEOToken.sol';
import {TestHelper} from 'unit-helpers/TestHelper.sol';

contract UnitGEOToken is TestHelper {
  address public council = makeAddr('council');
  address public minter = makeAddr('minter');
  address public initialSupplyRecipient = makeAddr('initialSupplyRecipient');
  uint256 public initialSupply = 1000e18;

  MockGEOToken public geoTokenImplementation;
  MockGEOToken public geoTokenProxy;

  function setUp() external {
    // Deploy implementation
    geoTokenImplementation = new MockGEOToken();

    // Deploy proxy and initialize
    geoTokenProxy = MockGEOToken(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(geoTokenImplementation),
          abi.encodeCall(
            GEOToken.initialize,
            (IGEOToken.GEOTokenInitializationParams({
                council: council,
                minter: minter,
                initialSupplyRecipient: initialSupplyRecipient,
                initialSupply: initialSupply
              }))
          )
        ))
    );
  }

  // -------- constants --------
  function test_Constants_WhenDeployed() external view {
    // when deployed
    // it sets _GEO_TOKEN_STORAGE_LOCATION to keccak256(abi.encode(uint256(keccak256("geo.storage.GEOToken")) - 1)) & ~bytes32(uint256(0xff))
    assertEq(
      geoTokenImplementation.exposed__GEO_TOKEN_STORAGE_LOCATION(),
      keccak256(abi.encode(uint256(keccak256('geo.storage.GEOToken')) - 1)) & ~bytes32(uint256(0xff))
    );
  }

  function test_Constructor_WhenCalled() external {
    // it disables initializers
    GEOToken newImplementation = new GEOToken();
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    newImplementation.initialize(
      IGEOToken.GEOTokenInitializationParams({
        council: council, minter: minter, initialSupplyRecipient: initialSupplyRecipient, initialSupply: initialSupply
      })
    );
  }

  function test_Initialize_WhenPassingValidParameters(
    address _council,
    address _minter,
    address _initialSupplyRecipientParam,
    uint256 _initialSupply
  ) external {
    // when passing valid parameters
    vm.assume(_council != address(0));
    vm.assume(_minter != address(0));
    vm.assume(_initialSupplyRecipientParam != address(0));
    vm.assume(_initialSupply > 0);

    // it emits the MinterSet event
    vm.expectEmit();
    emit IGEOToken.MinterSet(_minter);
    // Deploy new proxy with fuzzed parameters
    geoTokenProxy = MockGEOToken(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(geoTokenImplementation),
          abi.encodeCall(
            GEOToken.initialize,
            (IGEOToken.GEOTokenInitializationParams({
                council: _council,
                minter: _minter,
                initialSupplyRecipient: _initialSupplyRecipientParam,
                initialSupply: _initialSupply
              }))
          )
        ))
    );

    // it sets the token name and symbol
    assertEq(geoTokenProxy.name(), 'GEO Token');
    assertEq(geoTokenProxy.symbol(), 'GEO');

    // it sets the owner
    assertEq(geoTokenProxy.owner(), _council);

    // it sets the minter
    assertEq(geoTokenProxy.minter(), _minter);

    // it mints initial supply to initial supply recipient
    assertEq(geoTokenProxy.balanceOf(_initialSupplyRecipientParam), _initialSupply);
  }

  function test_Initialize_WhenCalledTwice() external {
    // when called twice
    // it reverts
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    geoTokenProxy.initialize(
      IGEOToken.GEOTokenInitializationParams({
        council: council, minter: minter, initialSupplyRecipient: initialSupplyRecipient, initialSupply: initialSupply
      })
    );
  }

  function test_Initialize_WhenOwnerIsZero() external {
    // when owner is zero it reverts with OwnableInvalidOwner
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
    UnsafeUpgrades.deployUUPSProxy(
      address(geoTokenImplementation),
      abi.encodeCall(
        GEOToken.initialize,
        (IGEOToken.GEOTokenInitializationParams({
            council: address(0),
            minter: minter,
            initialSupplyRecipient: initialSupplyRecipient,
            initialSupply: initialSupply
          }))
      )
    );
  }

  function test_Initialize_WhenMinterIsZero() external {
    // when minter is zero
    vm.expectRevert(IGEOToken.InvalidAddress.selector);
    UnsafeUpgrades.deployUUPSProxy(
      address(geoTokenImplementation),
      abi.encodeCall(
        GEOToken.initialize,
        (IGEOToken.GEOTokenInitializationParams({
            council: council,
            minter: address(0),
            initialSupplyRecipient: initialSupplyRecipient,
            initialSupply: initialSupply
          }))
      )
    );
  }

  function test_Initialize_WhenInitialSupplyRecipientIsZero() external {
    // when initial supply recipient is zero
    vm.expectRevert(IGEOToken.InvalidAddress.selector);
    UnsafeUpgrades.deployUUPSProxy(
      address(geoTokenImplementation),
      abi.encodeCall(
        GEOToken.initialize,
        (IGEOToken.GEOTokenInitializationParams({
            council: council, minter: minter, initialSupplyRecipient: address(0), initialSupply: initialSupply
          }))
      )
    );
  }

  modifier whenCalledByMinter() {
    vm.prank(minter);
    _;
  }

  function test_Mint_WhenAmountIsGreaterThanZero(address _recipient, uint256 _amount) external whenCalledByMinter {
    vm.assume(_recipient != address(0) && _recipient != initialSupplyRecipient);
    _amount = bound(_amount, 1, initialSupply);

    // it mints tokens to recipient and emits Transfer event
    vm.expectEmit(address(geoTokenProxy));
    emit IERC20.Transfer(address(0), _recipient, _amount);
    geoTokenProxy.mint(_recipient, _amount);

    assertEq(geoTokenProxy.balanceOf(_recipient), _amount);
  }

  function test_Mint_WhenAmountIsZero(address _recipient) external {
    vm.assume(_recipient != address(0) && _recipient != initialSupplyRecipient);
    vm.prank(minter);

    // it reverts with ZeroAmount
    vm.expectRevert(IGEOToken.ZeroAmount.selector);
    geoTokenProxy.mint(_recipient, 0);
  }

  function test_Mint_WhenCalledByNon_minter(address _caller, address _recipient, uint256 _amount) external {
    // when called by non-minter
    vm.assume(_caller != minter);
    vm.assume(_recipient != address(0));
    vm.assume(_amount > 0);
    vm.prank(_caller);

    // it reverts with OnlyMinter
    vm.expectRevert(IGEOToken.OnlyMinter.selector);
    geoTokenProxy.mint(_recipient, _amount);
  }

  function test_Burn_WhenAmountIsZero() external {
    // it reverts with ZeroAmount
    vm.expectRevert(IGEOToken.ZeroAmount.selector);
    geoTokenProxy.burn(0);
  }

  function test_Burn_WhenCallerHasSufficientBalance(address _burner, uint256 _amount) external {
    // when caller has sufficient balance
    vm.assume(_burner != address(0) && _burner != initialSupplyRecipient);
    _amount = bound(_amount, 1, initialSupply);

    geoTokenProxy.workaround_mintBalance(_burner, _amount);

    // Burn tokens
    vm.prank(_burner);
    vm.expectEmit(address(geoTokenProxy));
    emit IERC20.Transfer(_burner, address(0), _amount);
    geoTokenProxy.burn(_amount);

    // Check balance
    assertEq(geoTokenProxy.balanceOf(_burner), 0);
  }

  function test_Burn_WhenCallerHasInsufficientBalance(address _burner, uint256 _amount) external {
    vm.assume(_burner != address(0) && _burner != initialSupplyRecipient);
    vm.assume(_amount > 0);

    // Try to burn without having tokens
    vm.prank(_burner);
    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, _burner, 0, _amount));
    geoTokenProxy.burn(_amount);
  }

  function test_SetMinter_WhenCalledByOwner(address _minter) external {
    vm.assume(_minter != address(0));
    vm.assume(_minter != minter);

    assertEq(geoTokenProxy.minter(), minter);

    // it emits the MinterSet event
    vm.expectEmit();
    emit IGEOToken.MinterSet(_minter);
    vm.prank(council);
    geoTokenProxy.setMinter(_minter);

    // it sets the new minter address
    assertEq(geoTokenProxy.minter(), _minter);
  }

  function test_SetMinter_WhenCalledByNon_owner(address _caller, address _minter) external {
    vm.assume(_caller != council);
    vm.prank(_caller);

    // it reverts with OwnableUnauthorizedAccount
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    geoTokenProxy.setMinter(_minter);
  }

  function test_SetMinter_WhenMinterIsZero() external {
    // when minter is zero
    vm.prank(council);

    // it reverts with InvalidAddress
    vm.expectRevert(IGEOToken.InvalidAddress.selector);
    geoTokenProxy.setMinter(address(0));
  }

  function test_TypeId_WhenCalled() external view {
    // when called

    // it returns the type
    assertEq(geoTokenProxy.typeId(), keccak256('GEO_TOKEN'));
  }

  function test_Version_WhenCalled() external view {
    // when called

    // it returns semantic version
    assertEq(geoTokenProxy.version(), '1.0.0');
  }

  function test_Nonces_WhenCalled(address _account, uint256 _nonce) external {
    _assumeFuzzable(_account);
    vm.assume(_nonce != 0);

    // it returns the nonce
    assertEq(geoTokenProxy.nonces(_account), 0);

    geoTokenProxy.workaround_seedNonce(_account, _nonce);

    assertEq(geoTokenProxy.nonces(_account), _nonce);
  }

  function test__authorizeUpgrade_WhenCalledByOwner() external {
    address newImplementation = address(new GEOToken());
    vm.prank(council);

    // it authorizes the upgrade
    geoTokenProxy.upgradeToAndCall(newImplementation, '');
  }

  function test__authorizeUpgrade_WhenCalledByNon_owner(address _caller) external {
    vm.assume(_caller != council);
    address newImplementation = address(new GEOToken());
    vm.prank(_caller);

    // it reverts with OwnableUnauthorizedAccount
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    geoTokenProxy.upgradeToAndCall(newImplementation, '');
  }

  function test_Mint_WhenCalledByMinter(address _recipient, uint256 _amount) external whenCalledByMinter {
    vm.assume(_recipient != address(0) && _recipient != initialSupplyRecipient);
    _amount = bound(_amount, 1, initialSupply);

    // it mints tokens to recipient
    vm.expectEmit(address(geoTokenProxy));
    emit IERC20.Transfer(address(0), _recipient, _amount);
    geoTokenProxy.mint(_recipient, _amount);

    assertEq(geoTokenProxy.balanceOf(_recipient), _amount);
  }

  function test_Mint_WhenCalledByNonMinter(address _caller, address _recipient, uint256 _amount) external {
    // when called by non-minter
    vm.assume(_caller != minter);
    vm.assume(_recipient != address(0));
    vm.assume(_amount > 0);
    vm.prank(_caller);

    // it reverts
    vm.expectRevert(IGEOToken.OnlyMinter.selector);
    geoTokenProxy.mint(_recipient, _amount);
  }
}
