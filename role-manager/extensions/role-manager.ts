import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import {
  ROLE_MANAGER_STATE_CUSTOM_TYPE,
  discoverRoleSources,
  findRole,
  formatActiveRoleSystemPrompt,
  loadRoleRegistry,
  resolveActiveRoleName,
  resolveActiveRoleState,
} from "../lib/role-loader.mjs";
import { formatRoleWarning } from "../lib/role-schema.mjs";

const extensionDir = dirname(fileURLToPath(import.meta.url));
const packageRoot = join(extensionDir, "..");
const bundledRolesDir = join(packageRoot, "roles");
const ROLE_STATE_VERSION = 1;

interface RuntimeSettingsSnapshot {
  provider?: string;
  model?: string;
  thinkingLevel?: string;
  tools?: string[];
}

interface ParsedRoleCycleArgs {
  roleName: string;
  goal: string;
}

const MAX_ROLE_SESSION_NAME_LENGTH = 80;

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

function notifyInfo(ctx: ExtensionContext, message: string) {
  try {
    if (ctx.hasUI) {
      ctx.ui.notify(message, "info");
    } else {
      console.warn(message);
    }
  } catch (_error) {
    console.warn(message);
  }
}

function notifyError(ctx: ExtensionContext, message: string) {
  try {
    if (ctx.hasUI) {
      ctx.ui.notify(message, "error");
    } else {
      console.error(message);
    }
  } catch (_error) {
    console.error(message);
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

function normalizeText(value: unknown) {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function collapseWhitespace(value: string) {
  return value.replace(/\s+/g, " ").trim();
}

function parseRoleCycleArgs(args: string): ParsedRoleCycleArgs | undefined {
  const trimmed = args.trim();
  if (!trimmed) return undefined;

  const match = /^(\S+)(?:\s+([\s\S]+))?$/.exec(trimmed);
  if (!match) return undefined;

  const roleName = normalizeText(match[1]);
  const goal = normalizeText(match[2]);
  if (!roleName || !goal) return undefined;

  return { roleName, goal };
}

function formatRoleCyclePrompt(role: any, goal: string) {
  const roleName = role.name ?? "unknown";
  const roleTitle = role.icon ? `${role.icon} ${roleName}` : roleName;

  return `## Role cycle kickoff

Active role: ${roleTitle}
Goal: ${goal.trim()}

Run exactly one bounded cycle for the active role.

Operating constraints:

- Follow the active role instructions and its one-cycle workflow.
- Work only on the stated goal; do not start unrelated tasks.
- Project changes are allowed only when directly needed for the goal and
  permitted by the current repository instructions.
- Coordination changes are allowed only when directly needed for the goal and
  permitted by the current coordination rules.
- Use only context available in this session. If this is a fresh session, do
  not assume parent-session conversation details unless they are included here.
- Finish with the role's expected final report and then stop. Do not begin a
  second role cycle.
- If a \`role_cycle_done\` tool is available, call it as the final action with
  the cycle summary, files inspected, files changed, checks run, coordination
  updates, and recommended next role. If the tool is not available, include
  those fields in the final report instead.
`;
}

function formatRoleSessionName(roleName: string, goal: string) {
  const prefix = `[${roleName}] `;
  const fallbackGoal = "role cycle";
  const normalizedGoal = collapseWhitespace(goal) || fallbackGoal;
  const maxGoalLength = Math.max(1, MAX_ROLE_SESSION_NAME_LENGTH - prefix.length);

  if (normalizedGoal.length <= maxGoalLength) {
    return `${prefix}${normalizedGoal}`;
  }

  if (maxGoalLength > 3) {
    return `${prefix}${normalizedGoal.slice(0, maxGoalLength - 3).trimEnd()}...`;
  }

  return `${prefix}${normalizedGoal.slice(0, maxGoalLength)}`;
}

function formatRoleCycleCommand(roleName: string, goal: string) {
  return `/role-cycle ${roleName} ${goal.trim()}`;
}

function uniqueToolNames(tools: string[]) {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const tool of tools) {
    if (seen.has(tool)) continue;
    seen.add(tool);
    result.push(tool);
  }
  return result;
}

function sameModel(left: unknown, right: unknown) {
  const leftModel = left as { provider?: unknown; id?: unknown } | undefined;
  const rightModel = right as { provider?: unknown; id?: unknown } | undefined;
  return (
    leftModel?.provider === rightModel?.provider && leftModel?.id === rightModel?.id
  );
}

export default function roleManager(pi: ExtensionAPI) {
  let roleRegistry = loadRoleRegistry([]);
  let warnedMissingActiveRoles = new Set<string>();
  let activeRoleOriginalSettings: RuntimeSettingsSnapshot | undefined;

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

  function snapshotRuntimeSettings(ctx: ExtensionContext): RuntimeSettingsSnapshot {
    return {
      provider: normalizeText(ctx.model?.provider),
      model: normalizeText(ctx.model?.id),
      thinkingLevel: normalizeText(pi.getThinkingLevel()),
      tools: pi.getActiveTools(),
    };
  }

  function currentRoleState(ctx: ExtensionContext) {
    return resolveActiveRoleState({
      entries: getSessionEntries(ctx),
      env: process.env,
    });
  }

  function availableRoleNames() {
    return roleRegistry.roles.map((role) => role.name).sort((a, b) => a.localeCompare(b));
  }

  function formatAvailableRoles() {
    const names = availableRoleNames();
    return names.length > 0 ? names.join(", ") : "(none loaded)";
  }

  function roleArgumentCompletions(prefix: string) {
    const trimmedPrefix = prefix.trimStart();
    if (/\s/.test(trimmedPrefix)) return null;

    const normalizedPrefix = trimmedPrefix.toLowerCase();
    const items = roleRegistry.roles
      .filter((role) => role.name.toLowerCase().startsWith(normalizedPrefix))
      .map((role) => ({
        value: role.name,
        label: role.icon ? `${role.icon} ${role.name}` : role.name,
        description: role.description,
      }));
    return items.length > 0 ? items : null;
  }

  function resolveRoleModel(role: { name?: string; provider?: string; model?: string }, ctx: ExtensionContext) {
    const provider = normalizeText(role.provider);
    const modelId = normalizeText(role.model);

    if (!provider && !modelId) {
      return { model: undefined, warning: undefined };
    }

    if (provider && !modelId) {
      return {
        model: undefined,
        warning: `role-manager: role ${role.name ?? JSON.stringify(provider)} specifies provider without model`,
      };
    }

    if (provider && modelId) {
      const model = ctx.modelRegistry.find(provider, modelId);
      return {
        model,
        warning: model
          ? undefined
          : `role-manager: model not found for role setting: ${provider}/${modelId}`,
      };
    }

    const allModels = ctx.modelRegistry.getAll();
    const exactMatches = allModels.filter((candidate) => candidate.id === modelId);
    if (exactMatches.length === 1) {
      return { model: exactMatches[0], warning: undefined };
    }
    if (exactMatches.length > 1) {
      return {
        model: undefined,
        warning: `role-manager: role model ${JSON.stringify(modelId)} is ambiguous; add provider`,
      };
    }

    const slashIndex = modelId?.indexOf("/") ?? -1;
    if (slashIndex > 0 && slashIndex < (modelId?.length ?? 0) - 1) {
      const parsedProvider = modelId!.slice(0, slashIndex);
      const parsedModel = modelId!.slice(slashIndex + 1);
      const model = ctx.modelRegistry.find(parsedProvider, parsedModel);
      return {
        model,
        warning: model
          ? undefined
          : `role-manager: model not found for role setting: ${modelId}`,
      };
    }

    return {
      model: undefined,
      warning: `role-manager: model not found for role setting: ${modelId}`,
    };
  }

  async function applyRoleRuntimeSettings(role: any, ctx: ExtensionContext) {
    if (role.thinking && pi.getThinkingLevel() !== role.thinking) {
      pi.setThinkingLevel(role.thinking);
    }

    if (Array.isArray(role.tools) && role.tools.length > 0) {
      const requestedTools = uniqueToolNames(role.tools);
      const allToolNames = new Set(pi.getAllTools().map((tool) => tool.name));
      const validTools = requestedTools.filter((tool) => allToolNames.has(tool));
      const invalidTools = requestedTools.filter((tool) => !allToolNames.has(tool));

      if (invalidTools.length > 0) {
        notifyWarning(
          ctx,
          `role-manager: role ${role.name} requested unknown tools: ${invalidTools.join(", ")}`,
        );
      }

      if (validTools.length > 0) {
        pi.setActiveTools(validTools);
      }
    }

    const modelResolution = resolveRoleModel(role, ctx);
    if (modelResolution.warning) {
      notifyWarning(ctx, modelResolution.warning);
    }
    if (modelResolution.model && !sameModel(ctx.model, modelResolution.model)) {
      const success = await pi.setModel(modelResolution.model);
      if (!success) {
        notifyWarning(
          ctx,
          `role-manager: no API key for role model ${modelResolution.model.provider}/${modelResolution.model.id}`,
        );
      }
    }
  }

  async function restoreRuntimeSettings(
    settings: RuntimeSettingsSnapshot | undefined,
    ctx: ExtensionContext,
  ) {
    if (!settings) return false;

    let restoredAny = false;

    if (settings.provider && settings.model) {
      const model = ctx.modelRegistry.find(settings.provider, settings.model);
      if (model) {
        if (!sameModel(ctx.model, model)) {
          const success = await pi.setModel(model);
          if (!success) {
            notifyWarning(
              ctx,
              `role-manager: no API key for previous model ${settings.provider}/${settings.model}`,
            );
          }
        }
        restoredAny = true;
      } else {
        notifyWarning(
          ctx,
          `role-manager: previous model not found: ${settings.provider}/${settings.model}`,
        );
      }
    }

    if (settings.thinkingLevel) {
      pi.setThinkingLevel(settings.thinkingLevel as any);
      restoredAny = true;
    }

    if (Array.isArray(settings.tools)) {
      const allToolNames = new Set(pi.getAllTools().map((tool) => tool.name));
      const validTools = uniqueToolNames(settings.tools).filter((tool) => allToolNames.has(tool));
      const invalidTools = uniqueToolNames(settings.tools).filter((tool) => !allToolNames.has(tool));

      if (invalidTools.length > 0) {
        notifyWarning(
          ctx,
          `role-manager: previous tool selection contains unknown tools: ${invalidTools.join(", ")}`,
        );
      }

      if (validTools.length > 0 || settings.tools.length === 0) {
        pi.setActiveTools(validTools);
        restoredAny = true;
      }
    }

    return restoredAny;
  }

  function persistRoleState(
    roleName: string | null,
    previousSettings: RuntimeSettingsSnapshot | undefined,
    extra: Record<string, unknown> = {},
  ) {
    pi.appendEntry(ROLE_MANAGER_STATE_CUSTOM_TYPE, {
      version: ROLE_STATE_VERSION,
      activeRoleName: roleName,
      previousSettings,
      updatedAt: new Date().toISOString(),
      ...extra,
    });
  }

  async function activateRole(
    roleName: string,
    ctx: ExtensionContext,
    extraState: Record<string, unknown> = {},
  ) {
    const role = findRole(roleRegistry, roleName);
    if (!role) {
      notifyError(
        ctx,
        `role-manager: unknown role ${JSON.stringify(roleName)}. Available: ${formatAvailableRoles()}`,
      );
      return false;
    }

    const state = currentRoleState(ctx);
    const previousSettings = state.roleName
      ? state.previousSettings ?? activeRoleOriginalSettings ?? snapshotRuntimeSettings(ctx)
      : snapshotRuntimeSettings(ctx);

    activeRoleOriginalSettings = previousSettings;
    persistRoleState(role.name, previousSettings, {
      activatedAt: new Date().toISOString(),
      ...extraState,
    });
    await applyRoleRuntimeSettings(role, ctx);
    notifyInfo(ctx, `role-manager: activated role ${role.name}`);
    return true;
  }

  async function clearRole(ctx: ExtensionContext) {
    const state = currentRoleState(ctx);
    const previousSettings = state.roleName
      ? state.previousSettings ?? activeRoleOriginalSettings
      : activeRoleOriginalSettings;

    persistRoleState(null, previousSettings, { clearedAt: new Date().toISOString() });
    activeRoleOriginalSettings = undefined;

    const restored = await restoreRuntimeSettings(previousSettings, ctx);
    if (restored) {
      notifyInfo(ctx, "role-manager: role cleared and previous settings restored");
    } else {
      notifyInfo(ctx, "role-manager: role cleared");
    }
  }

  async function restoreActiveRoleFromState(ctx: ExtensionContext) {
    const state = currentRoleState(ctx);
    if (!state.roleName) {
      activeRoleOriginalSettings = undefined;
      return;
    }

    const role = findRole(roleRegistry, state.roleName);
    activeRoleOriginalSettings = state.previousSettings ?? snapshotRuntimeSettings(ctx);
    if (!role) return;

    await applyRoleRuntimeSettings(role, ctx);
  }

  pi.registerCommand("role", {
    description: "Switch the active role",
    getArgumentCompletions: roleArgumentCompletions,
    handler: async (args, ctx) => {
      await ctx.waitForIdle();

      const requestedRoleName = normalizeText(args);
      if (requestedRoleName) {
        await activateRole(requestedRoleName, ctx);
        return;
      }

      const names = availableRoleNames();
      if (names.length === 0) {
        notifyWarning(ctx, "role-manager: no roles are loaded");
        return;
      }

      if (!ctx.hasUI) {
        notifyInfo(ctx, `role-manager: available roles: ${names.join(", ")}`);
        return;
      }

      const selected = await ctx.ui.select("Select role:", names);
      if (!selected) return;
      await activateRole(selected, ctx);
    },
  });

  pi.registerCommand("role-clear", {
    description: "Clear the active role and restore previous settings",
    handler: async (_args, ctx) => {
      await ctx.waitForIdle();
      await clearRole(ctx);
    },
  });

  pi.registerCommand("role-cycle", {
    description: "Activate a role and run one bounded role cycle in this session",
    getArgumentCompletions: roleArgumentCompletions,
    handler: async (args, ctx) => {
      await ctx.waitForIdle();

      const parsed = parseRoleCycleArgs(args);
      if (!parsed) {
        notifyError(ctx, "Usage: /role-cycle <role> <goal>");
        return;
      }

      const role = findRole(roleRegistry, parsed.roleName);
      if (!role) {
        notifyError(
          ctx,
          `role-manager: unknown role ${JSON.stringify(parsed.roleName)}. Available: ${formatAvailableRoles()}`,
        );
        return;
      }

      const startedAt = new Date().toISOString();
      const activated = await activateRole(role.name, ctx, {
        roleCycle: {
          mode: "current-session",
          goal: parsed.goal,
          startedAt,
        },
      });
      if (!activated) return;

      pi.sendUserMessage(formatRoleCyclePrompt(role, parsed.goal));
    },
  });

  pi.registerCommand("role-new", {
    description: "Start a fresh session and run one bounded role cycle there",
    getArgumentCompletions: roleArgumentCompletions,
    handler: async (args, ctx) => {
      await ctx.waitForIdle();

      const parsed = parseRoleCycleArgs(args);
      if (!parsed) {
        notifyError(ctx, "Usage: /role-new <role> <goal>");
        return;
      }

      const role = findRole(roleRegistry, parsed.roleName);
      if (!role) {
        notifyError(
          ctx,
          `role-manager: unknown role ${JSON.stringify(parsed.roleName)}. Available: ${formatAvailableRoles()}`,
        );
        return;
      }

      const parentSession = ctx.sessionManager.getSessionFile();
      const sessionName = formatRoleSessionName(role.name, parsed.goal);
      const roleCycleCommand = formatRoleCycleCommand(role.name, parsed.goal);

      const result = await ctx.newSession({
        parentSession,
        setup: async (sessionManager) => {
          sessionManager.appendSessionInfo(sessionName);
        },
        withSession: async (replacementCtx) => {
          replacementCtx.ui.notify(
            `role-manager: starting fresh ${role.name} role cycle`,
            "info",
          );
          await replacementCtx.sendUserMessage(roleCycleCommand);
        },
      });

      if (result.cancelled) {
        notifyInfo(ctx, "role-manager: new role session cancelled");
      }
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    refreshRoles(ctx);
    await restoreActiveRoleFromState(ctx);
  });

  pi.on("session_tree", async (_event, ctx) => {
    await restoreActiveRoleFromState(ctx);
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
