// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {IDAO} from '@aragon/osx/core/dao/IDAO.sol';
import {PermissionManager} from '@aragon/osx/core/permission/PermissionManager.sol';
import {PluginCloneable} from '@aragon/osx/core/plugin/PluginCloneable.sol';
import {ProposalUpgradeable} from '@aragon/osx/core/plugin/proposal/ProposalUpgradeable.sol';
import {SafeCastUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol';

import {SpacePlugin} from 'contracts/space/SpacePlugin.sol';
import {IEditors} from 'interfaces/base/IEditors.sol';
import {IMembers} from 'interfaces/base/IMembers.sol';
import {IPersonalSpaceAdminPlugin} from 'interfaces/personal/IPersonalSpaceAdminPlugin.sol';
import {EDITOR_PERMISSION_ID, MEMBER_PERMISSION_ID} from 'src/constants.sol';

/// @title PersonalSpaceAdminPlugin
/// @notice The admin governance plugin giving execution permission on the DAO to a single address.
contract PersonalSpaceAdminPlugin is PluginCloneable, ProposalUpgradeable, IPersonalSpaceAdminPlugin {
  using SafeCastUpgradeable for uint256;

  /// @notice Checks and reverts if the caller is not a member
  modifier onlyMembers() {
    if (!isMember(msg.sender)) {
      revert NotAMember(msg.sender);
    }
    _;
  }

  /// @inheritdoc IPersonalSpaceAdminPlugin
  function initialize(
    IDAO _dao,
    address[] calldata _initialEditors,
    address[] calldata _initialMembers
  ) external initializer {
    __PluginCloneable_init(_dao);

    emit EditorsAdded(address(_dao), _initialEditors);
    emit MembersAdded(address(_dao), _initialMembers);
  }

  /// @notice Checks if this or the parent contract supports an interface by its ID.
  /// @param _interfaceId The ID of the interface.
  /// @return Returns `true` if the interface is supported.
  function supportsInterface(bytes4 _interfaceId)
    public
    view
    override(PluginCloneable, ProposalUpgradeable)
    returns (bool)
  {
    return _interfaceId == type(IPersonalSpaceAdminPlugin).interfaceId || super.supportsInterface(_interfaceId);
  }

  /// @inheritdoc IMembers
  function isMember(address _account) public view returns (bool) {
    return dao().hasPermission(address(this), _account, MEMBER_PERMISSION_ID, bytes('')) || isEditor(_account);
  }

  /// @inheritdoc IEditors
  function isEditor(address _account) public view returns (bool) {
    // Does the address hold the permission on the plugin?
    return dao().hasPermission(address(this), _account, EDITOR_PERMISSION_ID, bytes(''));
  }

  /// @inheritdoc IPersonalSpaceAdminPlugin
  function executeProposal(
    bytes calldata _metadata,
    IDAO.Action[] calldata _actions,
    uint256 _allowFailureMap
  ) external auth(EDITOR_PERMISSION_ID) {
    uint64 _currentTimestamp64 = block.timestamp.toUint64();

    uint256 _proposalId = _createProposal({
      _creator: msg.sender,
      _metadata: _metadata,
      _startDate: _currentTimestamp64,
      _endDate: _currentTimestamp64,
      _actions: _actions,
      _allowFailureMap: _allowFailureMap
    });
    dao().execute(bytes32(_proposalId), _actions, _allowFailureMap);
  }

  /// @inheritdoc IPersonalSpaceAdminPlugin
  function submitEdits(
    string memory _editsContentUri,
    bytes memory _editsMetadata,
    address _spacePlugin
  ) public onlyMembers {
    IDAO.Action[] memory _actions = new IDAO.Action[](1);

    _actions[0].to = _spacePlugin;
    _actions[0].data = abi.encodeCall(SpacePlugin.publishEdits, (_editsContentUri, _editsMetadata));

    uint256 _proposalId = _createProposal(msg.sender, _actions);

    dao().execute(bytes32(_proposalId), _actions, 0);

    // The event will be emitted by the space plugin
  }

  /// @inheritdoc IPersonalSpaceAdminPlugin
  function submitFlagContent(string memory _flagContentUri, address _spacePlugin) public onlyMembers {
    IDAO.Action[] memory _actions = new IDAO.Action[](1);

    _actions[0].to = _spacePlugin;
    _actions[0].data = abi.encodeCall(SpacePlugin.flagContent, (_flagContentUri));

    uint256 _proposalId = _createProposal(msg.sender, _actions);

    dao().execute(bytes32(_proposalId), _actions, 0);

    // The event will be emitted by the space plugin
  }

  /// @inheritdoc IPersonalSpaceAdminPlugin
  function submitAcceptSubspace(IDAO _subspaceDao, address _spacePlugin) public onlyMembers {
    IDAO.Action[] memory _actions = new IDAO.Action[](1);
    _actions[0].to = _spacePlugin;
    _actions[0].data = abi.encodeCall(SpacePlugin.acceptSubspace, (address(_subspaceDao)));

    uint256 _proposalId = _createProposal(msg.sender, _actions);

    dao().execute(bytes32(_proposalId), _actions, 0);

    // The event will be emitted by the space plugin
  }

  /// @inheritdoc IPersonalSpaceAdminPlugin
  function submitRemoveSubspace(IDAO _subspaceDao, address _spacePlugin) public onlyMembers {
    IDAO.Action[] memory _actions = new IDAO.Action[](1);
    _actions[0].to = _spacePlugin;
    _actions[0].data = abi.encodeCall(SpacePlugin.removeSubspace, (address(_subspaceDao)));

    uint256 _proposalId = _createProposal(msg.sender, _actions);

    dao().execute(bytes32(_proposalId), _actions, 0);

    // The event will be emitted by the space plugin
  }

  /// @inheritdoc IPersonalSpaceAdminPlugin
  function submitNewMember(address _newMember) public auth(EDITOR_PERMISSION_ID) {
    IDAO.Action[] memory _actions = new IDAO.Action[](1);
    _actions[0].to = address(dao());
    _actions[0].data = abi.encodeCall(PermissionManager.grant, (address(this), _newMember, MEMBER_PERMISSION_ID));

    uint256 _proposalId = _createProposal(msg.sender, _actions);

    dao().execute(bytes32(_proposalId), _actions, 0);

    emit MemberAdded(address(dao()), _newMember);
  }

  /// @inheritdoc IPersonalSpaceAdminPlugin
  function submitRemoveMember(address _member) public auth(EDITOR_PERMISSION_ID) {
    IDAO.Action[] memory _actions = new IDAO.Action[](1);
    _actions[0].to = address(dao());
    _actions[0].data = abi.encodeCall(PermissionManager.revoke, (address(this), _member, MEMBER_PERMISSION_ID));

    uint256 _proposalId = _createProposal(msg.sender, _actions);

    dao().execute(bytes32(_proposalId), _actions, 0);

    emit MemberRemoved(address(dao()), _member);
  }

  /// @inheritdoc IPersonalSpaceAdminPlugin
  function leaveSpace() external {
    IDAO.Action[] memory _actions;
    if (dao().hasPermission(address(this), msg.sender, MEMBER_PERMISSION_ID, bytes(''))) {
      _actions = new IDAO.Action[](1);
      _actions[0].to = address(dao());
      _actions[0].data = abi.encodeCall(PermissionManager.revoke, (address(this), msg.sender, MEMBER_PERMISSION_ID));

      uint256 _proposalId = _createProposal(msg.sender, _actions);
      dao().execute(bytes32(_proposalId), _actions, 0);
      emit MemberLeft(address(dao()), msg.sender);
    }

    if (isEditor(msg.sender)) {
      _actions = new IDAO.Action[](1);
      _actions[0].to = address(dao());
      _actions[0].data = abi.encodeCall(PermissionManager.revoke, (address(this), msg.sender, EDITOR_PERMISSION_ID));

      uint256 _proposalId = _createProposal(msg.sender, _actions);
      dao().execute(bytes32(_proposalId), _actions, 0);
      emit EditorLeft(address(dao()), msg.sender);
    }
  }

  /// @inheritdoc IPersonalSpaceAdminPlugin
  function submitNewEditor(address _newEditor) public auth(EDITOR_PERMISSION_ID) {
    IDAO.Action[] memory _actions = new IDAO.Action[](1);
    _actions[0].to = address(dao());
    _actions[0].data = abi.encodeCall(PermissionManager.grant, (address(this), _newEditor, EDITOR_PERMISSION_ID));

    uint256 _proposalId = _createProposal(msg.sender, _actions);

    dao().execute(bytes32(_proposalId), _actions, 0);

    emit EditorAdded(address(dao()), _newEditor);
  }

  /// @inheritdoc IPersonalSpaceAdminPlugin
  function submitRemoveEditor(address _editor) public auth(EDITOR_PERMISSION_ID) {
    IDAO.Action[] memory _actions = new IDAO.Action[](1);
    _actions[0].to = address(dao());
    _actions[0].data = abi.encodeCall(PermissionManager.revoke, (address(this), _editor, EDITOR_PERMISSION_ID));

    uint256 _proposalId = _createProposal(msg.sender, _actions);

    dao().execute(bytes32(_proposalId), _actions, 0);

    emit EditorRemoved(address(dao()), _editor);
  }

  // Internal helpers

  /// @notice Internal, simplified function to create a proposal.
  /// @param _creator The address who created the proposal.
  /// @param _actions The actions that will be executed after the proposal passes.
  /// @return proposalId The ID of the proposal.
  function _createProposal(address _creator, IDAO.Action[] memory _actions) internal returns (uint256 proposalId) {
    proposalId = _createProposalId();
    uint64 _currentTimestamp64 = block.timestamp.toUint64();

    emit ProposalCreated({
      proposalId: proposalId,
      creator: _creator,
      metadata: '',
      startDate: _currentTimestamp64,
      endDate: _currentTimestamp64,
      actions: _actions,
      allowFailureMap: 0
    });
  }
}
