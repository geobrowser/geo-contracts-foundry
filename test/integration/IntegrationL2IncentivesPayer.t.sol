// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {IArbSys} from 'interfaces/cross-chain/IArbSys.sol';
import {IPaymentManager} from 'interfaces/cross-chain/IPaymentManager.sol';

import 'script/Constants.s.sol' as Constants;
import 'src/ActionsConstants.sol' as ActionsConstants;

contract IntegrationL2IncentivesPayer is IntegrationBase {
  address internal constant _ARB_SYS = address(100);

  address internal _paymentManager = makeAddr('paymentManager');
  address internal _payer = makeAddr('incentivesPayer');

  function setUp() public override {
    IntegrationBase.setUp();
    vm.selectFork(_geoForkId);

    vm.prank(Constants.GEO_GEO_MULTISIG_COUNCIL);
    spaceRegistryProxy.setPaymentManager(_paymentManager);
  }

  function test_SetL2IncentivesPayer_WhenDaoSpaceIsActive() external {
    bytes32 _targetId = bytes32(_daoSpaceProxyId);
    bytes memory _calldataForL2 = abi.encodeCall(IPaymentManager.setPayer, (_targetId, _payer));

    vm.mockCall(_ARB_SYS, abi.encodeCall(IArbSys.sendTxToL1, (_paymentManager, _calldataForL2)), abi.encode(uint256(1)));

    vm.expectEmit();
    emit ISpaceRegistry.Action(
      _daoSpaceProxyId,
      _daoSpaceProxyId,
      ActionsConstants.L2_INCENTIVES_PAYER_SET,
      _targetId,
      abi.encode(_payer, uint256(1))
    );

    vm.prank(address(daoSpaceProxy));
    spaceRegistryProxy.setL2IncentivesPayer(_payer);
  }

  function test_SetL2IncentivesPayer_WhenPaymentManagerNotSet() external {
    vm.prank(Constants.GEO_GEO_MULTISIG_COUNCIL);
    spaceRegistryProxy.setPaymentManager(address(0));

    vm.prank(address(daoSpaceProxy));
    vm.expectRevert(ISpaceRegistry.PaymentManagerNotSet.selector);
    spaceRegistryProxy.setL2IncentivesPayer(_payer);
  }
}
