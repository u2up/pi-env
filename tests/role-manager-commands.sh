#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

REPO_ROOT="$repo_root" node --input-type=module <<'NODE'
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createJiti } from "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/jiti/lib/jiti.mjs";
import { ROLE_MANAGER_STATE_CUSTOM_TYPE } from "./role-manager/lib/role-loader.mjs";

const repoRoot = process.env.REPO_ROOT;
const jiti = createJiti(import.meta.url);
const roleManager = (await jiti.import("./role-manager/extensions/role-manager.ts")).default;

function roleMarkdown({ name, marker }) {
  return `---
name: ${name}
description: Project ${name}
icon: 🧪
thinking: high
tools: ["read", "bash", "missing_tool"]
provider: anthropic
model: target
---
# Project ${name}

## Mission

${marker} mission.

## Allowed actions

${marker} allowed.

## Forbidden actions

${marker} forbidden.

## One-cycle workflow

${marker} workflow.

## Expected final report

${marker} final report.

## Coordination behavior

${marker} coordination.
`;
}

const tmp = mkdtempSync(join(tmpdir(), "pi-env-role-commands-"));
const cwd = join(tmp, "project");
mkdirSync(join(cwd, ".pi", "roles"), { recursive: true });
writeFileSync(
  join(cwd, ".pi", "roles", "modeler.md"),
  roleMarkdown({ name: "modeler", marker: "PROJECT modeler" }),
);

const previousEnv = {
  PI_CODING_AGENT_DIR: process.env.PI_CODING_AGENT_DIR,
  PI_BWRAP_COMMON_AGENT_DIR: process.env.PI_BWRAP_COMMON_AGENT_DIR,
  PI_COORD_DIR: process.env.PI_COORD_DIR,
};
process.env.PI_CODING_AGENT_DIR = join(tmp, "agent");
delete process.env.PI_BWRAP_COMMON_AGENT_DIR;
process.env.PI_COORD_DIR = join(tmp, "coordination");

const models = [
  { provider: "anthropic", id: "original", name: "Original", api: "anthropic-messages", baseUrl: "", reasoning: true, input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 1000, maxTokens: 100 },
  { provider: "anthropic", id: "target", name: "Target", api: "anthropic-messages", baseUrl: "", reasoning: true, input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 1000, maxTokens: 100 },
];

function createHarness(initialEntries = []) {
  const entries = initialEntries;
  const commands = new Map();
  const handlers = new Map();
  const notifications = [];
  const sentUserMessages = [];
  const newSessionRequests = [];
  const newSessionSetups = [];
  const replacementNotifications = [];
  const replacementSentUserMessages = [];
  const state = {
    currentModel: models[0],
    thinkingLevel: "low",
    activeTools: ["read", "edit"],
    selection: undefined,
    sessionFile: join(tmp, "sessions", "original.jsonl"),
    newSessionCancelled: false,
  };

  const pi = {
    on(event, handler) {
      if (!handlers.has(event)) handlers.set(event, []);
      handlers.get(event).push(handler);
    },
    registerCommand(name, options) {
      commands.set(name, options);
    },
    appendEntry(customType, data) {
      entries.push({ type: "custom", customType, data });
    },
    sendUserMessage(content, options) {
      sentUserMessages.push({ content, options });
    },
    getThinkingLevel() {
      return state.thinkingLevel;
    },
    setThinkingLevel(level) {
      state.thinkingLevel = level;
    },
    getActiveTools() {
      return [...state.activeTools];
    },
    getAllTools() {
      return ["read", "bash", "edit", "write", "grep", "find", "ls"].map((name) => ({
        name,
        description: name,
        parameters: {},
        sourceInfo: { source: "builtin" },
      }));
    },
    setActiveTools(tools) {
      state.activeTools = [...tools];
    },
    async setModel(model) {
      state.currentModel = model;
      return true;
    },
  };

  const ctx = {
    get model() {
      return state.currentModel;
    },
    cwd,
    hasUI: true,
    modelRegistry: {
      find(provider, id) {
        return models.find((model) => model.provider === provider && model.id === id);
      },
      getAll() {
        return models;
      },
    },
    sessionManager: {
      getBranch() {
        return entries;
      },
      getEntries() {
        return entries;
      },
      getSessionFile() {
        return state.sessionFile;
      },
    },
    ui: {
      notify(message, type) {
        notifications.push({ message, type });
      },
      async select(_title, options) {
        return state.selection ?? options[0];
      },
    },
    isIdle() {
      return true;
    },
    async waitForIdle() {},
    async newSession(options = {}) {
      newSessionRequests.push(options);
      if (state.newSessionCancelled) {
        return { cancelled: true };
      }

      const replacementEntries = [];
      const sessionInfoNames = [];
      const setupSessionManager = {
        appendSessionInfo(name) {
          sessionInfoNames.push(name);
          replacementEntries.push({ type: "session_info", name });
        },
        appendCustomEntry(customType, data) {
          replacementEntries.push({ type: "custom", customType, data });
        },
        getEntries() {
          return replacementEntries;
        },
        buildSessionContext() {
          return { messages: [] };
        },
      };

      if (options.setup) {
        await options.setup(setupSessionManager);
      }
      newSessionSetups.push({ sessionInfoNames: [...sessionInfoNames], entries: [...replacementEntries] });

      if (options.withSession) {
        const replacementCtx = {
          cwd,
          hasUI: true,
          model: state.currentModel,
          modelRegistry: ctx.modelRegistry,
          sessionManager: {
            getBranch() {
              return replacementEntries;
            },
            getEntries() {
              return replacementEntries;
            },
            getSessionFile() {
              return join(tmp, "sessions", "replacement.jsonl");
            },
          },
          ui: {
            notify(message, type) {
              replacementNotifications.push({ message, type });
            },
          },
          isIdle() {
            return true;
          },
          async waitForIdle() {},
          async sendUserMessage(content, options) {
            replacementSentUserMessages.push({ content, options });
          },
        };
        await options.withSession(replacementCtx);
      }

      return { cancelled: false };
    },
  };

  async function emit(event, payload) {
    for (const handler of handlers.get(event) ?? []) {
      await handler(payload, ctx);
    }
  }

  async function buildSystemPrompt(base = "base system prompt") {
    let systemPrompt = base;
    for (const handler of handlers.get("before_agent_start") ?? []) {
      const result = await handler(
        {
          type: "before_agent_start",
          prompt: "test",
          systemPrompt,
          systemPromptOptions: {},
        },
        ctx,
      );
      if (result?.systemPrompt) systemPrompt = result.systemPrompt;
    }
    return systemPrompt;
  }

  roleManager(pi);

  return {
    entries,
    commands,
    handlers,
    notifications,
    sentUserMessages,
    newSessionRequests,
    newSessionSetups,
    replacementNotifications,
    replacementSentUserMessages,
    state,
    ctx,
    emit,
    buildSystemPrompt,
  };
}

try {
  const harness = createHarness([]);
  await harness.emit("session_start", { type: "session_start", reason: "startup" });

  assert.ok(harness.commands.has("role"), "/role command is registered");
  assert.ok(harness.commands.has("role-clear"), "/role-clear command is registered");
  assert.ok(harness.commands.has("role-cycle"), "/role-cycle command is registered");
  assert.ok(harness.commands.has("role-new"), "/role-new command is registered");

  await harness.commands.get("role").handler("modeler", harness.ctx);

  const activeEntry = harness.entries.find(
    (entry) => entry.customType === ROLE_MANAGER_STATE_CUSTOM_TYPE,
  );
  assert.equal(activeEntry.data.activeRoleName, "modeler");
  assert.deepEqual(activeEntry.data.previousSettings, {
    provider: "anthropic",
    model: "original",
    thinkingLevel: "low",
    tools: ["read", "edit"],
  });
  assert.equal(harness.state.currentModel.id, "target");
  assert.equal(harness.state.thinkingLevel, "high");
  assert.deepEqual(harness.state.activeTools, ["read", "bash"]);
  assert.ok(
    harness.notifications.some((notice) => notice.message.includes("missing_tool")),
    "unknown role tools are reported",
  );

  const prompt = await harness.buildSystemPrompt();
  assert.match(prompt, /Active Role: 🧪 modeler/);
  assert.match(prompt, /PROJECT modeler mission/);

  const restart = createHarness([...harness.entries]);
  restart.state.currentModel = models[0];
  restart.state.thinkingLevel = "off";
  restart.state.activeTools = ["ls"];
  await restart.emit("session_start", { type: "session_start", reason: "reload" });
  assert.equal(restart.state.currentModel.id, "target");
  assert.equal(restart.state.thinkingLevel, "high");
  assert.deepEqual(restart.state.activeTools, ["read", "bash"]);

  await harness.commands.get("role-clear").handler("", harness.ctx);
  const clearEntry = harness.entries.at(-1);
  assert.equal(clearEntry.data.activeRoleName, null);
  assert.equal(harness.state.currentModel.id, "original");
  assert.equal(harness.state.thinkingLevel, "low");
  assert.deepEqual(harness.state.activeTools, ["read", "edit"]);
  assert.doesNotMatch(await harness.buildSystemPrompt(), /Active Role:/);

  harness.state.selection = "developer";
  await harness.commands.get("role").handler("", harness.ctx);
  assert.equal(harness.entries.at(-1).data.activeRoleName, "developer");
  assert.equal(harness.state.thinkingLevel, "medium");

  const cycle = createHarness([]);
  await cycle.emit("session_start", { type: "session_start", reason: "startup" });
  await cycle.commands.get("role-cycle").handler("modeler design role manager", cycle.ctx);

  const cycleEntry = cycle.entries.find(
    (entry) => entry.customType === ROLE_MANAGER_STATE_CUSTOM_TYPE,
  );
  assert.equal(cycleEntry.data.activeRoleName, "modeler");
  assert.equal(cycleEntry.data.roleCycle.mode, "current-session");
  assert.equal(cycleEntry.data.roleCycle.goal, "design role manager");
  assert.equal(typeof cycleEntry.data.roleCycle.startedAt, "string");
  assert.equal(cycle.state.currentModel.id, "target");
  assert.equal(cycle.state.thinkingLevel, "high");
  assert.deepEqual(cycle.state.activeTools, ["read", "bash"]);
  assert.equal(cycle.sentUserMessages.length, 1);
  assert.match(cycle.sentUserMessages[0].content, /Role cycle kickoff/);
  assert.match(cycle.sentUserMessages[0].content, /Goal: design role manager/);
  assert.match(cycle.sentUserMessages[0].content, /exactly one bounded cycle/);
  assert.match(cycle.sentUserMessages[0].content, /role_cycle_done/);

  const fresh = createHarness([]);
  await fresh.emit("session_start", { type: "session_start", reason: "startup" });
  await fresh.commands.get("role-new").handler("modeler design role manager", fresh.ctx);

  assert.equal(fresh.newSessionRequests.length, 1);
  assert.equal(fresh.newSessionRequests[0].parentSession, fresh.state.sessionFile);
  assert.deepEqual(fresh.newSessionSetups[0].sessionInfoNames, ["[modeler] design role manager"]);
  assert.deepEqual(fresh.entries, [], "fresh session command must not mutate the original session state");
  assert.deepEqual(fresh.sentUserMessages, [], "fresh session command must not use the old pi sender");
  assert.deepEqual(fresh.replacementSentUserMessages, [
    { content: "/role-cycle modeler design role manager", options: undefined },
  ]);
  assert.ok(
    fresh.replacementNotifications.some((notice) =>
      notice.message.includes("starting fresh modeler role cycle"),
    ),
  );

  const cancelled = createHarness([]);
  await cancelled.emit("session_start", { type: "session_start", reason: "startup" });
  cancelled.state.newSessionCancelled = true;
  await cancelled.commands.get("role-new").handler("modeler design role manager", cancelled.ctx);

  assert.equal(cancelled.newSessionRequests.length, 1);
  assert.equal(cancelled.newSessionSetups.length, 0);
  assert.deepEqual(cancelled.entries, []);
  assert.deepEqual(cancelled.sentUserMessages, []);
  assert.deepEqual(cancelled.replacementSentUserMessages, []);
  assert.equal(cancelled.state.currentModel.id, "original");
  assert.equal(cancelled.state.thinkingLevel, "low");
  assert.deepEqual(cancelled.state.activeTools, ["read", "edit"]);
  assert.ok(
    cancelled.notifications.some((notice) => notice.message.includes("new role session cancelled")),
  );

  console.log("role manager command tests passed");
} finally {
  for (const [key, value] of Object.entries(previousEnv)) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
}
NODE
