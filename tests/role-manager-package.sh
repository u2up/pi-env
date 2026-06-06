#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

REPO_ROOT="$repo_root" node --input-type=module <<'NODE'
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import {
  ROLE_SOURCE_KINDS,
  discoverRoleSources,
  loadRoleRegistry,
} from "./role-manager/lib/role-loader.mjs";
import { formatRoleWarning, validateRoleFile } from "./role-manager/lib/role-schema.mjs";

const repoRoot = process.env.REPO_ROOT;
const packageRoot = join(repoRoot, "role-manager");
const manifest = JSON.parse(readFileSync(join(packageRoot, "package.json"), "utf8"));

assert.equal(manifest.name, "pi-env-role-manager");
assert.ok(manifest.keywords.includes("pi-package"), "package is not tagged as a Pi package");
assert.deepEqual(manifest.pi.extensions, ["./extensions/role-manager.ts"]);
assert.ok(existsSync(join(packageRoot, "extensions", "role-manager.ts")));
assert.ok(existsSync(join(packageRoot, "lib", "role-loader.mjs")));
assert.ok(existsSync(join(packageRoot, "roles", "architect.md")));

const flake = readFileSync(join(repoRoot, "flake.nix"), "utf8");
assert.match(flake, /mkRoleManagerPackage/);
assert.match(flake, /pi-role-manager = roleManagerPackage/);
assert.match(flake, /PI_ENV_ROLE_MANAGER_PACKAGE/);
assert.match(flake, /for common_dir_name in skills prompts roles; do/);

const exampleProject = join(repoRoot, "examples", "project-role-override");
const exampleRolePath = join(
  exampleProject,
  ".pi",
  "roles",
  "domain-architect.md",
);
const exampleValidation = validateRoleFile(exampleRolePath, { requireSections: true });
assert.equal(
  exampleValidation.valid,
  true,
  exampleValidation.warnings.map(formatRoleWarning).join("\n"),
);

const sources = discoverRoleSources({
  cwd: exampleProject,
  packageRolesDir: join(packageRoot, "roles"),
  agentDir: join(repoRoot, "tests", "fixtures", "empty-agent"),
  env: {},
  homeDir: join(repoRoot, "tests", "fixtures", "empty-home"),
});
const registry = loadRoleRegistry(sources);
const warnings = registry.warnings.map(formatRoleWarning).join("\n");
assert.equal(registry.invalidRoles.length, 0, warnings);
assert.ok(registry.rolesByName.has("architect"), warnings);
assert.ok(registry.rolesByName.has("domain-architect"), warnings);
assert.equal(
  registry.rolesByName.get("domain-architect").source.kind,
  ROLE_SOURCE_KINDS.PROJECT,
);
assert.match(registry.rolesByName.get("domain-architect").body, /project's domain model/);

console.log("role manager package tests passed");
NODE
