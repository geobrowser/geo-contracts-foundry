// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {MockDAOSpace} from 'mocks/MockDAOSpace.sol';

import 'src/ActionsConstants.sol' as ActionsConstants;

contract UnitDAOSpace is TestHelper {
  MockDAOSpace public daoSpaceImplementation;
  MockDAOSpace public daoSpaceProxy;
  address public daoSpaceBeacon;

  address internal _owner;
  uint256 internal _ownerPrivateKey;
  IDAOSpace.VotingSettings internal _votingSettings;
  address[] internal _initialEditors;
  address[] internal _initialMembers;

  address internal _randomCaller = makeAddr('_randomCaller');
  address internal _spaceRegistry = makeAddr('_spaceRegistry');
  address internal _fromSpace = makeAddr('_fromSpace');
  address internal _toSpace = makeAddr('_toSpace');
  address internal _initialEditor = makeAddr('_initialEditor');
  address internal _initialMember = makeAddr('_initialMember');

  function setUp() external {
    // set up
    (_owner, _ownerPrivateKey) = makeAddrAndKey('_owner');
    _votingSettings =
      IDAOSpace.VotingSettings({slowPathPercentageThreshold: 5e5, fastPathFlatThreshold: 1, duration: 2 days});
    _initialEditors = new address[](1);
    _initialEditors[0] = _initialEditor;
    _initialMembers = new address[](1);
    _initialMembers[0] = _initialMember;

    // proxy set up
    daoSpaceImplementation = new MockDAOSpace();
    daoSpaceBeacon = UnsafeUpgrades.deployBeacon(address(daoSpaceImplementation), _owner);

    // deploy with owner to fetch future address for external calls and event emissions
    vm.startPrank(_owner, _owner);
    address predictedDAOSpaceProxy = vm.computeCreateAddress(_owner, vm.getNonce(_owner));

    // when delegate called
    _mockRegisterSpaceId(_spaceRegistry);

    // it calls enter on the spaceRegistry with the ADD_EDITOR action
    _mockEnter(
      _spaceRegistry,
      predictedDAOSpaceProxy,
      predictedDAOSpaceProxy,
      ActionsConstants.ADD_EDITOR,
      bytes32(bytes20(_initialEditor))
    );

    // it calls enter on the spaceRegistry with the ADD_MEMBER action
    _mockEnter(
      _spaceRegistry,
      predictedDAOSpaceProxy,
      predictedDAOSpaceProxy,
      ActionsConstants.ADD_MEMBER,
      bytes32(bytes20(_initialMember))
    );

    // when deployed
    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize, (ISpaceRegistry(_spaceRegistry), _votingSettings, _initialEditors, _initialMembers)
        )
      )
    );
    vm.stopPrank();
  }

  /// CONSTRUCTOR ///

  function test_Constructor_WhenCalled() external {
    // it disables initializers
    vm.expectEmit();
    emit Initializable.Initialized(type(uint64).max);

    // when called
    new MockDAOSpace();
  }

  /// INITIALIZE ///

  modifier whenDelegateCalled() {
    // when delegate called
    _;
  }

  function test_Initializer_WhenDelegateCalled(
    address __spaceRegistry,
    IDAOSpace.VotingSettings calldata __votingSettings
  ) external whenDelegateCalled {
    _assumeFuzzable(__spaceRegistry);
    address[] memory __initialEditors = new address[](0);
    address[] memory __initialMembers = new address[](0);

    // it calls spaceRegistry to register space ID
    _mockRegisterSpaceId(__spaceRegistry);

    // when delegate called
    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize, (ISpaceRegistry(__spaceRegistry), __votingSettings, __initialEditors, __initialMembers)
        )
      )
    );

    // it sets the spaceRegistry
    assertEq(address(daoSpaceProxy.spaceRegistry()), __spaceRegistry);

    // it sets the voting settings
    (uint256 slowPathPercentageThreshold, uint256 fastPathFlatThreshold, uint256 duration) =
      daoSpaceProxy.votingSettings();
    assertEq(slowPathPercentageThreshold, __votingSettings.slowPathPercentageThreshold);
    assertEq(fastPathFlatThreshold, __votingSettings.fastPathFlatThreshold);
    assertEq(duration, __votingSettings.duration);

    // it grants itself the DAO role
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.DAO(), address(daoSpaceProxy)), true);

    // it sets addMember as a valid fast path action
    assertEq(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.addMember.selector), true);

    // it sets removeMember as a valid fast path action
    assertEq(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.removeMember.selector), true);
  }

  function test_Initializer_WhenInitialEditorsLengthIsGreaterThanZero(
    address __spaceRegistry,
    IDAOSpace.VotingSettings calldata __votingSettings,
    address __initialEditor
  ) external whenDelegateCalled {
    _assumeFuzzable(__spaceRegistry);
    _assumeFuzzable(__initialEditor);
    address[] memory __initialEditors = new address[](1);
    __initialEditors[0] = __initialEditor;
    address[] memory __initialMembers = new address[](0);

    // deploy with owner to fetch future address for external calls and event emissions
    vm.startPrank(_owner, _owner);
    address predictedDAOSpaceProxy = vm.computeCreateAddress(_owner, vm.getNonce(_owner));

    // it calls spaceRegistry to register space ID
    _mockRegisterSpaceId(__spaceRegistry);

    // it calls enter on the spaceRegistry with the ADD_EDITOR action
    _mockEnter(
      __spaceRegistry,
      predictedDAOSpaceProxy,
      predictedDAOSpaceProxy,
      ActionsConstants.ADD_EDITOR,
      bytes32(bytes20(__initialEditor))
    );

    // when delegate called
    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize, (ISpaceRegistry(__spaceRegistry), __votingSettings, __initialEditors, __initialMembers)
        )
      )
    );

    // it grants the new editor the EDITOR role
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), __initialEditor), true);
  }

  function test_Initializer_WhenInitialMembersLengthIsGreaterThanZero(
    address __spaceRegistry,
    IDAOSpace.VotingSettings calldata __votingSettings,
    address __initialMember
  ) external whenDelegateCalled {
    _assumeFuzzable(__spaceRegistry);
    _assumeFuzzable(__initialMember);
    address[] memory __initialEditors = new address[](0);
    address[] memory __initialMembers = new address[](1);
    __initialMembers[0] = __initialMember;

    // deploy with owner to fetch future address for external calls and event emissions
    vm.startPrank(_owner, _owner);
    address predictedDAOSpaceProxy = vm.computeCreateAddress(_owner, vm.getNonce(_owner));

    // it calls spaceRegistry to register space ID
    _mockRegisterSpaceId(__spaceRegistry);

    // it calls enter on the spaceRegistry with the ADD_MEMBER action
    _mockEnter(
      __spaceRegistry,
      predictedDAOSpaceProxy,
      predictedDAOSpaceProxy,
      ActionsConstants.ADD_MEMBER,
      bytes32(bytes20(__initialMember))
    );

    // when delegate called
    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize, (ISpaceRegistry(__spaceRegistry), __votingSettings, __initialEditors, __initialMembers)
        )
      )
    );

    // it grants the new member the MEMBER role
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), __initialMember), true);
  }

  function test_Initializer_WhenDelegateCalledAgain(
    address __spaceRegistry,
    IDAOSpace.VotingSettings calldata __votingSettings
  ) external whenDelegateCalled {
    _assumeFuzzable(__spaceRegistry);
    address[] memory __initialEditors = new address[](0);
    address[] memory __initialMembers = new address[](0);

    // it calls spaceRegistry to register space ID
    _mockRegisterSpaceId(__spaceRegistry);

    // when delegate called
    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize, (ISpaceRegistry(__spaceRegistry), __votingSettings, __initialEditors, __initialMembers)
        )
      )
    );

    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when delegate called again
    daoSpaceProxy.initialize(ISpaceRegistry(__spaceRegistry), __votingSettings, __initialEditors, __initialMembers);
  }

  function test_Initializer_WhenCalled() external {
    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when called again
    daoSpaceProxy.initialize(ISpaceRegistry(_spaceRegistry), _votingSettings, _initialEditors, _initialMembers);
  }

  /// WRITE - CREATE PROPOSAL ///

  modifier whenCalledBySpaceRegistry() {
    vm.startPrank(_spaceRegistry);
    _;
    vm.stopPrank();
  }

  modifier when_actionEqualsCREATE_PROPOSAL() {
    _;
  }

  function test_Write_When_actionEqualsCREATE_PROPOSAL(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsCREATE_PROPOSAL
  {
    // get initial proposal count
    uint256 initialProposalCounter = daoSpaceProxy.proposalCounter();

    // when called
    bytes memory _proposalData = _createSlowPathProposalToAddEditor();
    daoSpaceProxy.write(_initialEditor, ActionsConstants.CREATE_PROPOSAL, _topic, _proposalData);

    // it incremments the proposal counter
    assertEq(daoSpaceProxy.proposalCounter(), initialProposalCounter + 1);

    (, IDAOSpace.ProposalParameters memory parameters,, IDAOSpace.Action[] memory actions) =
      daoSpaceProxy.getProposalInformation(initialProposalCounter);

    // it sets the proposal start date to block.timestamp
    assertEq(parameters.startDate, vm.getBlockTimestamp());

    // it sets the proposal last date to block.timestamp plus votingSettings.duration
    assertEq(parameters.lastDate, vm.getBlockTimestamp() + _votingSettings.duration);

    // it sets the proposal voting mode
    assertEq(uint256(parameters.votingMode), uint256(IDAOSpace.VotingMode.Slow));

    // it stores the decoded proposal actions
    assertEq(actions.length, 1);
    assertEq(actions[0].to, address(daoSpaceProxy));
    assertEq(actions[0].value, 0);
    assertEq(actions[0].data, abi.encodeCall(IDAOSpace.addEditor, (_randomCaller)));
  }

  modifier whenTheVotingModeIsSlow() {
    _;
  }

  function test_Write_WhenTheVotingModeIsSlow(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsCREATE_PROPOSAL
    whenTheVotingModeIsSlow
  {
    bytes memory _proposalData = _createSlowPathProposalToAddEditor();
    daoSpaceProxy.write(_initialEditor, ActionsConstants.CREATE_PROPOSAL, _topic, _proposalData);

    (, IDAOSpace.ProposalParameters memory parameters,,) =
      daoSpaceProxy.getProposalInformation(daoSpaceProxy.proposalCounter() - 1);

    // it sets the proposal support threshold to the slow path percentage threshold
    assertEq(parameters.supportThreshold, _votingSettings.slowPathPercentageThreshold);
  }

  function test_Write_When_fromSpaceIsNotAMemberOrEditor(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsCREATE_PROPOSAL
    whenTheVotingModeIsSlow
  {
    bytes memory _proposalData = _createSlowPathProposalToAddEditor();

    // it reverts with InvalidFromSpace
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);
    daoSpaceProxy.write(_randomCaller, ActionsConstants.CREATE_PROPOSAL, _topic, _proposalData);
  }

  modifier whenTheVotingModeIsFast() {
    _;
  }

  function test_Write_WhenTheVotingModeIsFast(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsCREATE_PROPOSAL
    whenTheVotingModeIsFast
  {
    bytes memory _proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_initialEditor, ActionsConstants.CREATE_PROPOSAL, _topic, _proposalData);

    (, IDAOSpace.ProposalParameters memory parameters,,) =
      daoSpaceProxy.getProposalInformation(daoSpaceProxy.proposalCounter() - 1);

    // it sets the proposal support threshold to the fast path flat threshold
    assertEq(parameters.supportThreshold, _votingSettings.fastPathFlatThreshold);
  }

  function test_Write_When_fromSpaceIsNotAnEditor(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsCREATE_PROPOSAL
    whenTheVotingModeIsFast
  {
    bytes memory _proposalData = _createFastPathProposalToAddMember();

    // it reverts with InvalidFromSpace
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);
    daoSpaceProxy.write(_randomCaller, ActionsConstants.CREATE_PROPOSAL, _topic, _proposalData);
  }

  function test_Write_When_fromSpaceIsAFlaggedEditor(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsCREATE_PROPOSAL
    whenTheVotingModeIsFast
  {
    daoSpaceProxy.workaround_setEditorToFlagged(_initialEditor, true);

    bytes memory _proposalData = _createFastPathProposalToAddMember();

    // it reverts with EditorFlagged
    vm.expectRevert(IDAOSpace.EditorFlagged.selector);
    daoSpaceProxy.write(_initialEditor, ActionsConstants.CREATE_PROPOSAL, _topic, _proposalData);
  }

  function test_Write_WhenTheDecodedProposalActionIsNotLimitedToOneCall(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsCREATE_PROPOSAL
    whenTheVotingModeIsFast
  {
    bytes memory _proposalData = _createFastPathProposalToAddTwoMembers();

    // it reverts with OneActionForFastPath
    vm.expectRevert(IDAOSpace.OneActionForFastPath.selector);
    daoSpaceProxy.write(_initialEditor, ActionsConstants.CREATE_PROPOSAL, _topic, _proposalData);
  }

  function test_Write_WhenTheFunctionSelectorOfTheDecodedProposalActionIsNotFastPathValid(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsCREATE_PROPOSAL
    whenTheVotingModeIsFast
  {
    bytes memory _proposalData = _createFastPathProposalToAddEditor();

    // it reverts with InvalidAction
    vm.expectRevert(IDAOSpace.InvalidAction.selector);
    daoSpaceProxy.write(_initialEditor, ActionsConstants.CREATE_PROPOSAL, _topic, _proposalData);
  }

  /// WRITE - VOTE ///

  /// HELPERS ///

  function _mockRegisterSpaceId(address __spaceRegistry) internal {
    _mockAndExpect(__spaceRegistry, abi.encodeCall(ISpaceRegistry.registerSpaceId, ()), abi.encode());
  }

  function _mockEnter(address __spaceRegistry, address _from, address _to, bytes32 _action, bytes32 _topic) internal {
    _mockAndExpect(
      __spaceRegistry, abi.encodeCall(ISpaceRegistry.enter, (_from, _to, _action, _topic, '', '')), abi.encode()
    );
  }

  function _createSlowPathProposalToAddEditor() internal view returns (bytes memory) {
    IDAOSpace.VotingMode votingMode = IDAOSpace.VotingMode.Slow;
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addEditor, (_randomCaller))
    });
    return abi.encode(votingMode, actions);
  }

  /// @dev valid proposal because action is fast path valid
  function _createFastPathProposalToAddMember() internal view returns (bytes memory) {
    IDAOSpace.VotingMode votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_randomCaller))
    });
    return abi.encode(votingMode, actions);
  }

  /// @dev invalid proposal because it attempts to perform two actions
  function _createFastPathProposalToAddTwoMembers() internal view returns (bytes memory) {
    IDAOSpace.VotingMode votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](2);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_randomCaller))
    });
    actions[1] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_randomCaller))
    });
    return abi.encode(votingMode, actions);
  }

  /// @dev invalid proposal because action is not fast path valid
  function _createFastPathProposalToAddEditor() internal view returns (bytes memory) {
    IDAOSpace.VotingMode votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addEditor, (_randomCaller))
    });
    return abi.encode(votingMode, actions);
  }
}
