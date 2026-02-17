#!/usr/bin/env bash
#
# Prepare upgrade reference build-info for OpenZeppelin upgrade validation.
# See: https://docs.openzeppelin.com/upgrades-plugins/api-core#define-reference-contracts
#
# All upgrade scripts validate storage layout against a reference build in
# previous-builds/<name>/. Run this script from the repo root before running
# any Upgrade*.s.sol script or its unit test.
#
# What this script does:
#   1. Full rebuild (forge clean && forge build) so build-info is from a complete
#      compilation and includes storage layout — required by the validator.
#   2. For each upgradeable contract: empties previous-builds/<dir>, copies into it
#      only the one build-info file that contains that contract, so the validator
#      sees a single reference contract.
#
#   Script                            | Reference dir
#   ----------------------------------|---------------------------------------
#   UpgradeDAOSpace.s.sol             | previous-builds/dao-space
#   UpgradeVerifierSpace.s.sol        | previous-builds/verifier-space
#   UpgradeSpaceRegistry.s.sol        | previous-builds/space-registry
#   UpgradeDAOSpaceFactory.s.sol      | previous-builds/dao-space-factory
#   UpgradeVerifierSpaceFactory.s.sol | previous-builds/verifier-space-factory
#
# Usage:
#   ./script/prepare-upgrade-ref.sh
#
# Tests / same-version: Using the current build as reference is fine; layout matches.
# Real upgrade: Run this script on the commit that deployed the current
# implementation, then reuse that previous-builds/ tree when validating the new version.
#
set -e

forge clean && forge build

build_info_dir='out/build-info'

prepare_ref() {
  local dir=$1
  local pattern=$2
  local name=$3
  rm -rf "previous-builds/$dir"
  mkdir -p "previous-builds/$dir"
  ref=$(grep -l "$pattern" "$build_info_dir"/*.json 2>/dev/null | head -1)
  if [[ -z "$ref" ]]; then
    echo "Error: no build-info file found for $name" >&2
    exit 1
  fi
  cp -f "$ref" "previous-builds/$dir/"
}

prepare_ref 'dao-space'                 'DAOSpace.sol'                'DAOSpace'
prepare_ref 'verifier-space'            'VerifierSpace.sol'           'VerifierSpace'
prepare_ref 'space-registry'            'SpaceRegistry.sol'           'SpaceRegistry'
prepare_ref 'dao-space-factory'         'DAOSpaceFactory.sol'         'DAOSpaceFactory'
prepare_ref 'verifier-space-factory'    'VerifierSpaceFactory.sol'    'VerifierSpaceFactory'