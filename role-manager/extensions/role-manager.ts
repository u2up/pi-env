import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import {
  discoverRoleSources,
  findRole,
  formatActiveRoleSystemPrompt,
  loadRoleRegistry,
  resolveActiveRoleName,
} from "../lib/role-loader.mjs";
import { formatRoleWarning } from "../lib/role-schema.mjs";

const extensionDir = dirname(fileURLToPath(import.meta.url));
const packageRoot = join(extensionDir, "..");
const bundledRolesDir = join(packageRoot, "roles");

function notifyWarning(ctx: ExtensionContext, message: string) {
  try {
    if (ctx.hasUI) {
      ctx.ui.notify(message, "warning");
    } else {
      console.warn(message);
    }
  } catch (_error) {
    console.warn(message);
  }
}

function getSessionEntries(ctx: ExtensionContext) {
  try {
    return ctx.sessionManager.getBranch();
  } catch (_error) {
    try {
      return ctx.sessionManager.getEntries();
    } catch (_innerError) {
      return [];
    }
  }
}

export default function roleManager(pi: ExtensionAPI) {
  let roleRegistry = loadRoleRegistry([]);
  let warnedMissingActiveRoles = new Set<string>();

  function refreshRoles(ctx: ExtensionContext) {
    try {
      const sources = discoverRoleSources({
        cwd: ctx.cwd,
        packageRolesDir: bundledRolesDir,
      });
      roleRegistry = loadRoleRegistry(sources);
      warnedMissingActiveRoles = new Set<string>();

      for (const warning of roleRegistry.warnings) {
        notifyWarning(ctx, formatRoleWarning(warning));
      }
    } catch (error) {
      const details = error instanceof Error ? error.message : String(error);
      roleRegistry = loadRoleRegistry([]);
      notifyWarning(ctx, `role-manager: could not load role files: ${details}`);
    }
  }

  pi.on("session_start", async (_event, ctx) => {
    refreshRoles(ctx);
  });

  pi.on("before_agent_start", async (event, ctx) => {
    const activeRoleName = resolveActiveRoleName({
      entries: getSessionEntries(ctx),
      env: process.env,
    });
    if (!activeRoleName) return;

    const activeRole = findRole(roleRegistry, activeRoleName);
    if (!activeRole) {
      if (!warnedMissingActiveRoles.has(activeRoleName)) {
        warnedMissingActiveRoles.add(activeRoleName);
        notifyWarning(
          ctx,
          `role-manager: active role not found: ${activeRoleName}`,
        );
      }
      return;
    }

    return {
      systemPrompt:
        event.systemPrompt + "\n\n" + formatActiveRoleSystemPrompt(activeRole),
    };
  });
}
