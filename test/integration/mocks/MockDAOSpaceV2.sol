// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {ISemver} from 'interfaces/ISemver.sol';

import 'src/ActionsConstants.sol' as ActionsConstants;

/**
 * @title MockDAOSpaceV2
 * @notice Mock contract for testing new DAOSpace implementations
 */
contract MockDAOSpaceV2 is DAOSpace {
  /**
   * @notice The storage struct of the DAO space v2 contract
   * @param totalMembers Total members
   * @custom:storage-location erc7201:geo.storage.DAOSpaceV2
   */
  struct DAOSpaceV2Storage {
    uint256 totalMembers;
  }

  /**
   * @notice The storage location of the DAO space v2 contract
   * @custom:storage-location erc7201:geo.storage.DAOSpaceV2
   */
  bytes32 internal constant _DAO_SPACE_V2_STORAGE_LOCATION =
    0xbf0af05307d98909e87ed998e7924ab72bb5be08f7dcc007f77b7008ba1aec00;

  /**
   * @notice Reinitializes the contract
   * @param _initializerData The encoded initializer data:
   *        _initialTotalMembers The initial total number of members
   */
  function initialize(bytes calldata _initializerData) external virtual override reinitializer(2) {
    // Decode initializer data
    uint256 _initialTotalMembers = abi.decode(_initializerData, (uint256));

    // Set the initial total members
    DAOSpaceV2Storage storage $2 = _getDAOSpaceV2Storage();
    $2.totalMembers = _initialTotalMembers;

    // Set the initial fast path actions
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    $.actionIsFastPathValid[DAOSpace.addMember.selector] = false;
    $.actionIsFastPathValid[DAOSpace.removeMember.selector] = false;
    $.actionIsFastPathValid[DAOSpace.addEditor.selector] = true;
    $.actionIsFastPathValid[DAOSpace.removeEditor.selector] = true;

    // Ping the registry with the updated type
    _ping(ActionsConstants.SPACE_TYPE_DECLARED, keccak256(bytes(name())), abi.encode(version()));
  }

  /**
   * @notice Total members
   * @return _totalMembers The total number of members
   */
  function totalMembers() public view returns (uint256 _totalMembers) {
    DAOSpaceV2Storage storage $2 = _getDAOSpaceV2Storage();
    _totalMembers = $2.totalMembers;
  }

  /// @inheritdoc ISemver
  function version() public pure virtual override returns (string memory _version) {
    _version = '2.0.0';
  }

  /// @inheritdoc DAOSpace
  function _addMember(address _newMember) internal virtual override {
    DAOSpace._addMember(_newMember);
    // Update counter
    DAOSpaceV2Storage storage $2 = _getDAOSpaceV2Storage();
    $2.totalMembers++;
  }

  /// @inheritdoc DAOSpace
  function _removeMember(address _oldMember) internal virtual override {
    DAOSpace._removeMember(_oldMember);
    // Update counter
    DAOSpaceV2Storage storage $2 = _getDAOSpaceV2Storage();
    $2.totalMembers--;
  }

  /**
   * @notice Returns the DAO space v2 contract storage
   * @return $2 The storage of the DAO space v2 contract
   * @custom:storage-location erc7201:geo.storage.DAOSpaceV2
   */
  function _getDAOSpaceV2Storage() internal pure returns (DAOSpaceV2Storage storage $2) {
    assembly {
      $2.slot := _DAO_SPACE_V2_STORAGE_LOCATION
    }
  }
}
