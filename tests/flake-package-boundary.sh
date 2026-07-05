#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

REPO_ROOT="$repo_root" node --input-type=module <<'NODE'
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const repoRoot = process.env.REPO_ROOT;
const flake = readFileSync(join(repoRoot, "flake.nix"), "utf8");
const readme = readFileSync(join(repoRoot, "README.md"), "utf8");
const design = readFileSync(join(repoRoot, "designs", "nix-runtime.md"), "utf8");
const legacyCoordinationPackage = "pi" + "-coordination";
const legacyConfigFile = ".pi" + "-coordination.yaml";

assert.doesNotMatch(flake, new RegExp(`${legacyCoordinationPackage}(?: =|-smoke)`));
assert.doesNotMatch(readme, new RegExp(legacyCoordinationPackage));
assert.doesNotMatch(readme, new RegExp(legacyConfigFile.replace(/\./g, "\\.")));
assert.doesNotMatch(design, new RegExp(legacyCoordinationPackage));

assert.match(flake, /includeCoordinationHelpers \? true/);
assert.match(
  flake,
  /coordinationPackages = if includeCoordinationHelpers then agentCoordCommands else \[ \];/,
);
assert.match(flake, /pi-core = piCore;/);
assert.match(flake, /pi-env-coordination = piCoordination;/);
assert.match(flake, /pi-runtime = piRuntime;/);
assert.match(flake, /name = "pi-env-core";/);
assert.match(flake, /name = "pi-env-coordination";/);
assert.match(flake, /paths = coreRuntimePaths;/);
assert.match(flake, /paths = agentCoordCommandPackages;/);
assert.match(flake, /paths = coreRuntimePaths \+\+ agentCoordCommandPackages;/);
assert.match(flake, /"agent-coord-generate-requirements-coverage"/);
assert.match(flake, /pi-core-smoke/);
assert.match(flake, /pi-runtime-compat-smoke/);
assert.match(flake, /pi-env-coordination-smoke/);
assert.match(flake, /agent coordination helpers leaked into pi-core/);

assert.match(readme, /nix profile install ~\/src\/pi-env#pi-core/);
assert.match(readme, /nix profile install ~\/src\/pi-env#pi-env-coordination/);
assert.match(readme, /nix profile install ~\/src\/pi-env#pi-runtime/);
assert.match(readme, /includeCoordinationHelpers = false;/);
assert.match(readme, /`mkPiShell` defaults `includeCoordinationHelpers` to `true`/);
assert.match(readme, /pi-env\.packages\.\$\{system\}\.pi-core/);
assert.match(readme, /pi-env\.packages\.\$\{system\}\.pi-env-coordination/);
assert.match(readme, /`pi-runtime` continues to include the core runtime plus coordination helpers/);

assert.match(design, /`pi-core` contains `pi-env`, `pi-start`, `pi-bwrap`, and the runtime tools/);
assert.match(design, /`pi-env-coordination` contains the Git-backed coordination helper commands/);
assert.match(design, /`pi-runtime` remains the compatibility bundle/);
assert.match(design, /Projects that only need the sandbox\/runtime set it to `false`/);

console.log("flake package boundary tests passed");
NODE
