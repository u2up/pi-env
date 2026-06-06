import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import {
  formatRoleWarning,
  validateRoleDirectory,
} from "../lib/role-schema.mjs";

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

function validateBundledRoles(ctx: ExtensionContext) {
  try {
    const result = validateRoleDirectory(bundledRolesDir, {
      requireSections: true,
    });
    for (const warning of result.warnings) {
      notifyWarning(ctx, formatRoleWarning(warning));
    }
  } catch (error) {
    const details = error instanceof Error ? error.message : String(error);
    notifyWarning(
      ctx,
      `role-manager: could not validate bundled role files: ${details}`,
    );
  }
}

export default function roleManager(pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    validateBundledRoles(ctx);
  });
}
