# Background

The Geo governance contracts provide a modular platform built on top of GEO, an Arbitrum Orbit L3 that settles to Arbitrum One. The core purpose of this system is the emission of `Action` events from the `SpaceRegistry`, the central hub of this architecture, that are then indexed, interpreted, and organised in a knowledge graph offchain. In order to modify this offchain knowledge graph via `Action` events, Spaces must first be registered in the `SpaceRegistry`, which creates and enforces a bi-directional mapping between a bytes16 `spaceId` and an `account` address. Each Space’s `spaceId` is generated deterministically onchain when the Space is registered.

Crucially, however, as the Geo ecosystem was being developed, an early version of the governance contracts were deployed to a Geo testnet, and with it a significant number of Spaces and knowledge were created and indexed. While beneficial for the growth of Geo, this nonetheless poses a challenge for the mainnet contracts if this pre-existing data is to be incorporated into the `SpaceRegistry` on Geo’s mainnet L3. Specifically, because the `spaceIds` were derived via deterministic onchain hashing (involving the testnet’s chain id), the `spaceIds` associated with the testnet data can not be assigned to new Spaces on mainnet; the onchain derivation will always differ when a Space is created and registered. 

To avoid the need to re-create and re-index these Spaces and knowledge, and to open the possibility for multi-chain Geo deployments into the future, the `SpaceRegistry` will be modified to allow for known `spaceIds` to be registered by privileged actors in the system.

# General

Before turning to address recommended modifications to the `SpaceRegistry` contract, it will prove useful to briefly mention some conceptual and architectural challenges associated with supporting the Geo governance contracts on several chains simultaneously. These are as follows:

- **Rarity Race**: If it is made permissionless for any Space to choose their `spaceId` when registering, which might be desired for multi-chain registrations, this will create a race condition for Spaces to acquire the unique and potentially valuable identifiers before others (i.e. `bytes16(0)`, or `bytes16(420)`).
- **Cross-Chain Collision**: If there exist multiple `SpaceRegistries` across multiple chains (one on each), there exists a risk that two Spaces are created with the same `spaceId`. Alternatively, the same `account` address might be associated with different Spaces on different chains, which while less dangerous than a `spaceId` collision, could still cause confusion.
    
    <aside>
    📒
    
    Cross-chain messaging to redress these collisions are non-trivial to implement, do not scale well as the number supported chains increases, and will significantly degrade the user experience of registering.
    
    </aside>
    

With these challenges in mind, a new function, `overrideSpaceId` will be added to the `SpaceRegistry` that will allow the registry owner to register a new Space, or override the bi-directional mapping of an existing Space, with a `spaceId` and `account` they provide. This function will be restricted to only the Geo Multisig Council to mitigate against both the rarity race and cross-chain collision challenges mentioned above. Furthermore, the Geo Multisig Council may, in a future proxy upgrade, remove this `overrideSpaceId` function.

In addition, some small modifications to how a `DAOSpace` is created will also be required in order to facilitate cross-chain Space transplants.

<aside>
🚨

This addition places significant responsibility and risk with the Geo Multisig Council. Here are some potential failure cases to consider:

- The Geo Multisig Council overrides an existing Space with incorrect details.
    - Incorrect `spaceId` from a testnet
    - Incorrect `account` addresses on the mainnet
- The Geo Multisig Council overrides a Space on two different chains, causing a collision for the indexer.
</aside>

## **Requirements**

- Add the `overrideSpaceId` function to the SpaceRegistry.
- Modifications to `DAOSpaceFactory` and `DAOSpace` creation logic.
- Updated unit, integration, and invariant tests.

# In-Depth

The addition of the `overrideSpaceId` function will allow the Geo Multisig Council to register a new Space, or override the bi-directional mapping of an existing Space, with a `spaceId` and `account` they provide. This function can then facilitate the transplantation of `spaceIds` from a pre-existing chain to the new Geo L3, assisting in the preservation of knowledge that was already generated via the testnet.

<aside>
⚠️

What is presented below is neither the final nor the exhaustive implementation; however, it serves as a reference for how the modifications are intended to work.

</aside>

## Terminological Disambiguation

To avoid confusion over the terms employed below, note the definitions regarding moving a Space from one address to another on the same chain, as opposed to moving it from one chain to another.

- **Migrate/Migration:** A Space changes it’s `account` address while remaining on the same chain. The spaceId remains unchanged.
- **Transplant/Transplantation:** A Space moves from one chain to another, potentially also changing it’s `account` address in the process. The spaceId remains unchanged.

Thus, the `overrideSpaceId` function and additional changes outlined below will assist in providing a mechanism for transplantation of Spaces between chains.

## Smart Contract Changes

**Space Registry**

The `overrideSpaceId` function, as detailed below, will first clear any pre-existing relationship between the `spaceId` and `account` that might be present, before updating the registry with the new bi-directional mapping.

The `overrideSpaceId` function will also allow for an arbitrary number of `Action` events to be emitted in conjunction with the mapping relationship override (via `_actions`, `_subjects`, and `_datas`). This will allow for the Geo Multisig Council to emit the member/editor added events that would otherwise be omitted given the changes to the `DAOSpace` initialisation detailed below.

In addition to these events, a new `Action` event will be added, `SPACE_ID_OVERRIDDEN`, which will be emitted when `overrideSpaceId` is called by the registry owner.

Finally, no new storage variables are required with this change, meaning that this function can easily be removed in a future proxy upgrade. Given the risk/trust granted to the Geo Multisig Council with this change, this should be strongly considered moving forward.

```solidity
function overrideSpaceId(
  address _account,
  bytes16 _spaceId,
  bytes32 _type,
  bytes memory _version,
  bytes32[] _actions, 
  bytes32[] _subjects,
  bytes[] calldata _datas
) external virtual onlyOwner {
  SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();

  // Clear old relationship
  address _oldAccount = $.spaceIdToAddress[_spaceId];
  bytes16 _oldSpaceId = $.addressToSpaceId[_account];
  $.addressToSpaceId[_oldAccount] = bytes16(0);
  $.spaceIdToAddress[_oldSpaceId] = address(0);

  // Add new relationship
  $.addressToSpaceId[_account] = _spaceId;
  $.spaceIdToAddress[_spaceId] = _account;
	
	// Action event emissions
  emit Action(_spaceId, _spaceId, ActionsConstants.SPACE_ID_OVERRIDDEN, bytes32(bytes20(_account)), '');
  if (_type != bytes32(0)) emit Action(_spaceId, _spaceId, ActionsConstants.SPACE_TYPE_DECLARED, _type, _version);
	 
	// Emit arbitrary Action events for indexer consistency
  uint256 _length = _actions.length;
  if (_length != _subjects.length || _length != _datas.length) revert();
  for (uint256 _i; _i < _length; _i++) {
    emit Action(_spaceId, _spaceId, _actions[_i], _subjects[_i], _datas[_i]);
  }
}
```

<aside>
🔍

Note that migrations are not reset here. Meaning that it is possible for the following scenario to occur:

- A Space calls `proposeSpaceMigration` to migrate an existing Space to an new address on the same chain.
- The Geo Multisig Council calls `overrideSpaceId` to override this Space with a new `account` address (also on the same chain).
- The Space, after being overridden, calls `acceptSpaceMigration` and moves their `account` to the initially proposed address, thereby overriding the override.

Of course, this is not a vulnerability, per se, and nor is it the expected use of `overrideSpaceId`, which aims to provide the owner with a means of transplanting and preserving `spaceIds` across chains, rather than an alternative means of migrating a Space within a chain.

</aside>

**DAO Space**

To support the transplantation of DAO Spaces specifically, the system must allow a DAO to be created with a `spaceId` that is not derived onchain at creation time. Instead, the creator can supply a pre-determined `spaceId` (e.g. a pre-existing testnet `spaceId`) to prevent the DAO from registering itself when created. At a later stage, the Geo Multisig Council can call  `overrideSpaceId` to bind that `spaceId` to the new DAO on mainnet. This keeps the same `spaceId` across chains and avoids re-indexing.

So the change introduces two paths:

- **Standard Creation:** Caller passes `bytes16(0)` for the optional `_daoSpaceId`. The DAO calls `registerSpaceId` and uses the returned `spaceId` (unchanged behaviour).
- **Transplant Creation:** Caller passes the desired `spaceId` (e.g. from the testnet). Here the DAO does not register itself; it exists but is not yet in the registry until the owner calls `overrideSpaceId` with that `spaceId` and the new DAO’s address (new behaviour). To prevent the calls to the SpaceRegistry from failing, the members and editors are added to storage directly.

<aside>
🚨

Importantly, if a DAO Space is created with a chosen `spaceId`, and it is not or will not be the target of an `overrideSpaceId` call by the Geo Multisig Council, it will be unusable because it will not be registered in the `SpaceRegistry`.

</aside>

```solidity
/// @inheritdoc IDAOSpace
function initialize(bytes calldata _initializerData) external virtual initializer {
  // Decode initializer data
  (
    ISpaceRegistry _spaceRegistry,
    VotingSettings memory _votingSettings,
    bytes16[] memory _initialEditors,
    bytes16[] memory _initialMembers,
    bytes memory _publishEditsData,
    bytes16 _initialTopicId,
    bytes16 _daoSpaceId
  ) = abi.decode(_initializerData, (ISpaceRegistry, VotingSettings, bytes16[], bytes16[], bytes, bytes16, bytes16));

  // Set Space Registry
  DAOSpaceStorage storage $ = _getDAOSpaceStorage();
  $.spaceRegistry = _spaceRegistry;

  // Standard Creation
  if (_daoSpaceId == bytes16(0)) {
    // Register new DAO Space
    _daoSpaceId = $.spaceRegistry.registerSpaceId(typeId(), abi.encode(version()));

    // Ping the registry with initial edit if it exists
    if (_publishEditsData.length != 0) _ping(ActionsConstants.EDITS_PUBLISHED, '', _publishEditsData);

    // Ping the registry again to set an initial topic
    if (_initialTopicId != bytes16(0)) _ping(ActionsConstants.TOPIC_SET, bytes32(_initialTopicId), '');

    // Add initial editors
    uint256 length = _initialEditors.length;
    for (uint256 i; i < length; i++) {
      _addEditor(_initialEditors[i]);
    }

    // Add initial members
    length = _initialMembers.length;
    for (uint256 j; j < length; j++) {
      _addMember(_initialMembers[j]);
    }
  } else {
    // Transplant Creation
    // Add initial editors
    uint256 length = _initialEditors.length;
    $.totalEditors = length;
    for (uint256 i; i < length; i++) {
      _grantRole(EDITOR, _initialEditors[i]);
    }

    // Add initial members
    length = _initialMembers.length;
    for (uint256 j; j < length; j++) {
      _grantRole(MEMBER, _initialMembers[j]);
    }
  }
  
	// Set voting settings
  _updateVotingSettings(_votingSettings);

  // Grant further roles for access control
  _grantRole(SPACE_REGISTRY, _spaceRegistry.addressToSpaceId(address(_spaceRegistry)));
  _grantRole(DAO, _daoSpaceId);

  // Set the initial fast path actions
  $.actionIsFastPathValid[IDAOSpace.addMember.selector] = true;
  $.actionIsFastPathValid[IDAOSpace.removeMember.selector] = true;
  $.actionIsFastPathValid[IDAOSpace.ping.selector] = true;
}
```

**DAO Space Factory**
To prevent abuse, the `DAOSpaceFactory` contract will also be updated to first accommodate this new feature, and also to restrict usage of the transplant creation branch to the Geo Multisig Council.

```solidity
/// @inheritdoc IDAOSpaceFactory
function createDAOSpaceProxy(
  IDAOSpace.VotingSettings calldata _votingSettings,
  bytes16[] calldata _initialEditors,
  bytes16[] calldata _initialMembers,
  bytes calldata _initialEditsContentUri,
  bytes calldata _initialEditsMetadata,
  bytes16 _initialTopicId,
  bytes16 _daoSpaceId
) external virtual returns (address _newDAOSpaceProxy) {
  DAOSpaceFactoryStorage storage $ = _getDAOSpaceFactoryStorage();

  if ((msg.sender != owner()) && (_daoSpaceId != bytes16(0))) revert InvalidDAOSpaceId();
  
  ...
```

## Usage Guide

To help demonstrate the utility of the `overrideSpaceId` function, consider the following usage steps that the Geo Multisig Council can undertake to transplant a Space from the testnet to the Geo mainnet. The offchain processes and/or tooling required will be omitted presently.

<aside>
✍️

It is recommended that EOA Spaces are transplanted before DAO Spaces given that this will greatly assist with populating the transplanted DAO Spaces with their full list of members and editors.

</aside>

**Transplanting an EOA Space**

- Offchain, the Geo Multisig Council retrieves the `spaceId` and EOA `account` address of the Space to be transplanted.
    - This assumes that the same EOA address is to be used on both chains. If not, before transplanting, a Space may need to signal to the owner that they want to use a new address. Alternatively they can migrate their account address on the testnet before, or after, the transplantation.
- The Geo Multisig Council calls `overrideSpaceId` with the `spaceId` and EOA `account` address from the testnet, thereby transplanting the Space to the mainnet.
- In order to preserve the Space’s knowledge, and allow indexers to re-create Geo’s knowledge graph while only referencing one chain, the Space should emit a `PublishedEdits` event that links to, or summarises, all of the testnet data it previously produced.

**Transplanting a DAO Space**

- Offchain, the Geo Multisig Council retrieves the `spaceId`, and all DAO settings used including the full list of members and editors, of the Space to be transplanted.
    - Note here that this process is made significantly easier if all members and editors have been transplanted before the DAO.
- The Geo Multisig Council creates a DAO Space using the `DAOSpaceFactory` on mainnet, using the DAO settings and full list of members and editors, and passes in the DAO’s `spaceId` from the testnet. This will create a new DAO that is not yet registered in the `SpaceRegistry`.
- The Geo Multisig Council calls `overrideSpaceId` with the `spaceId` retrieved from the testnet (and passed to the DAO when it was created), and the `account` address of the newly created DAO Space on mainnet. This will transplant the Space to mainnet.
- In order to preserve the Space’s knowledge, and allow indexers to re-create Geo’s knowledge graph while only referencing one chain, the Space should emit a `PublishedEdits` event that links to, or summarises, all of the testnet data it previously produced. In addition, the added member and editor Actions should be emitted also.
    - All of these events can be emitted when the DAO’s spaceId is overridden with the use of `_actions`, `_subjects`, and `_datas`.

# Resources

- [Space Transplantation — Step by Step Guide](https://www.notion.so/Space-Transplantation-Step-by-Step-Guide-3119a4c092c78077a16bc302f58b3091?pvs=21)
- [Idea Draft: Migration Through Genesis State Injection](https://www.notion.so/Idea-Draft-Migration-Through-Genesis-State-Injection-30c9a4c092c7805b9a9edddc95bd8be2?pvs=21)
- [Batching Transactions in Privy/Safe Setup](https://www.notion.so/Batching-Transactions-in-Privy-Safe-Setup-30d273e214eb80b08faae12e508fb0c5?pvs=21)

# Milestones and Estimates

It is estimated to take one solidity developer 2 week/s to implement the changes outlined, including full unit, integration, and invariant testing

# External Requirements

- [ ]  `SPACE_ID_OVERRIDDEN` processing by the indexer (if added)

# Open Questions and Thoughts

- We won’t migrate `VerifierSpaces`
- Is the new `SPACE_ID_OVERRIDDEN` event needed? Do we have anywhere in the indexer a mapping between addresses and space ids?
- For already proposed edits on testnet:
    - Can we use them again?
    - Should we compact all the edits on a single edit?
        - Is there a script already developed that supports this?
