import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

export const REQUIRED_FRONTMATTER_FIELDS = ["name", "description"];
export const SUPPORTED_FRONTMATTER_FIELDS = [
  "name",
  "description",
  "icon",
  "thinking",
  "tools",
  "coordCommitter",
  "provider",
  "model",
];
export const THINKING_LEVELS = [
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
];
export const REQUIRED_BODY_SECTIONS = [
  "Mission",
  "Allowed actions",
  "Forbidden actions",
  "One-cycle workflow",
  "Expected final report",
  "Coordination behavior",
];

const ROLE_NAME_PATTERN = /^[a-z][a-z0-9_-]*$/;

function makeWarning(sourcePath, message, field) {
  return { sourcePath, message, field };
}

function stripQuotes(value) {
  const trimmed = value.trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

function parseArray(value) {
  const trimmed = value.trim();
  if (!trimmed.startsWith("[") || !trimmed.endsWith("]")) {
    return undefined;
  }

  try {
    const parsed = JSON.parse(trimmed);
    return Array.isArray(parsed) ? parsed : undefined;
  } catch (_error) {
    const inner = trimmed.slice(1, -1).trim();
    if (!inner) return [];
    return inner.split(",").map((item) => stripQuotes(item));
  }
}

function parseScalar(value) {
  const array = parseArray(value);
  if (array) return array;
  return stripQuotes(value);
}

function parseFrontmatterBlock(block, sourcePath) {
  const data = {};
  const warnings = [];
  let currentListKey;

  for (const rawLine of block.split(/\r?\n/)) {
    const trimmed = rawLine.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;

    const listItem = rawLine.match(/^\s*-\s+(.+)$/);
    if (currentListKey && listItem) {
      data[currentListKey].push(parseScalar(listItem[1]));
      continue;
    }

    currentListKey = undefined;
    const keyValue = rawLine.match(/^([A-Za-z][A-Za-z0-9_-]*):(?:\s*(.*))?$/);
    if (!keyValue) {
      warnings.push(
        makeWarning(
          sourcePath,
          `invalid frontmatter line: ${JSON.stringify(rawLine)}`,
        ),
      );
      continue;
    }

    const [, key, rawValue = ""] = keyValue;
    const value = rawValue.trim();
    if (!value) {
      data[key] = [];
      currentListKey = key;
      continue;
    }

    data[key] = parseScalar(value);
  }

  return { data, warnings };
}

export function parseRoleMarkdown(markdown, sourcePath = "<memory>") {
  const text = markdown.replace(/^\uFEFF/, "");
  const match = /^---\s*\r?\n([\s\S]*?)\r?\n---\s*(?:\r?\n|$)([\s\S]*)$/.exec(text);
  if (!match) {
    return {
      frontmatter: {},
      body: text,
      hasFrontmatter: false,
      warnings: [
        makeWarning(
          sourcePath,
          'invalid role file: missing YAML frontmatter delimited by "---"',
        ),
      ],
    };
  }

  const parsed = parseFrontmatterBlock(match[1], sourcePath);
  return {
    frontmatter: parsed.data,
    body: match[2].trimStart(),
    hasFrontmatter: true,
    warnings: parsed.warnings,
  };
}

function isPresentString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function normalizeTools(value) {
  if (value === undefined) return [];
  if (!Array.isArray(value)) return undefined;
  if (!value.every(isPresentString)) return undefined;
  return value.map((tool) => tool.trim());
}

function hasMarkdownSection(body, title) {
  const escaped = title.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp(`^#{2,3}\\s+${escaped}\\s*$`, "im").test(body);
}

export function validateRoleMarkdown(
  markdown,
  sourcePath = "<memory>",
  options = {},
) {
  const parsed = parseRoleMarkdown(markdown, sourcePath);
  const warnings = [...parsed.warnings];
  let valid = parsed.hasFrontmatter && parsed.warnings.length === 0;

  const addInvalid = (message, field) => {
    valid = false;
    warnings.push(makeWarning(sourcePath, `invalid role file: ${message}`, field));
  };

  for (const field of REQUIRED_FRONTMATTER_FIELDS) {
    if (!isPresentString(parsed.frontmatter[field])) {
      addInvalid(`missing required frontmatter field "${field}"`, field);
    }
  }

  if (isPresentString(parsed.frontmatter.name)) {
    const name = parsed.frontmatter.name.trim();
    if (!ROLE_NAME_PATTERN.test(name)) {
      addInvalid(
        'frontmatter field "name" must match /^[a-z][a-z0-9_-]*$/',
        "name",
      );
    }
  }

  if (
    parsed.frontmatter.thinking !== undefined &&
    parsed.frontmatter.thinking.length !== 0
  ) {
    if (
      !isPresentString(parsed.frontmatter.thinking) ||
      !THINKING_LEVELS.includes(parsed.frontmatter.thinking.trim())
    ) {
      addInvalid(
        `frontmatter field "thinking" must be one of ${THINKING_LEVELS.join(", ")}`,
        "thinking",
      );
    }
  }

  const tools = normalizeTools(parsed.frontmatter.tools);
  if (parsed.frontmatter.tools !== undefined && tools === undefined) {
    addInvalid('frontmatter field "tools" must be a list of tool names', "tools");
  }

  if (
    parsed.frontmatter.coordCommitter !== undefined &&
    parsed.frontmatter.coordCommitter.length !== 0 &&
    !isPresentString(parsed.frontmatter.coordCommitter)
  ) {
    addInvalid(
      'frontmatter field "coordCommitter" must be a non-empty string',
      "coordCommitter",
    );
  }

  if (!parsed.body.trim()) {
    addInvalid("body must contain model-readable role instructions");
  }

  const sections = REQUIRED_BODY_SECTIONS.filter((section) =>
    hasMarkdownSection(parsed.body, section),
  );
  const missingSections = REQUIRED_BODY_SECTIONS.filter(
    (section) => !sections.includes(section),
  );

  for (const section of missingSections) {
    const message = `missing body section "${section}"`;
    if (options.requireSections) {
      addInvalid(message);
    } else {
      warnings.push(makeWarning(sourcePath, message));
    }
  }

  const role = {
    sourcePath,
    name: isPresentString(parsed.frontmatter.name)
      ? parsed.frontmatter.name.trim()
      : undefined,
    description: isPresentString(parsed.frontmatter.description)
      ? parsed.frontmatter.description.trim()
      : undefined,
    icon: isPresentString(parsed.frontmatter.icon)
      ? parsed.frontmatter.icon.trim()
      : undefined,
    thinking: isPresentString(parsed.frontmatter.thinking)
      ? parsed.frontmatter.thinking.trim()
      : undefined,
    tools: tools ?? [],
    coordCommitter: isPresentString(parsed.frontmatter.coordCommitter)
      ? parsed.frontmatter.coordCommitter.trim()
      : undefined,
    provider: isPresentString(parsed.frontmatter.provider)
      ? parsed.frontmatter.provider.trim()
      : undefined,
    model: isPresentString(parsed.frontmatter.model)
      ? parsed.frontmatter.model.trim()
      : undefined,
    frontmatter: parsed.frontmatter,
    body: parsed.body,
    sections,
    missingSections,
  };

  return { valid, role, warnings };
}

export function validateRoleFile(filePath, options = {}) {
  try {
    return validateRoleMarkdown(readFileSync(filePath, "utf8"), filePath, options);
  } catch (error) {
    return {
      valid: false,
      role: undefined,
      warnings: [
        makeWarning(
          filePath,
          `invalid role file: could not read file: ${error.message}`,
        ),
      ],
    };
  }
}

export function validateRoleDirectory(roleDir, options = {}) {
  const result = {
    roleDir,
    roles: [],
    invalidRoles: [],
    warnings: [],
  };

  let entries;
  try {
    entries = readdirSync(roleDir, { withFileTypes: true });
  } catch (error) {
    result.warnings.push(
      makeWarning(roleDir, `could not read role directory: ${error.message}`),
    );
    return result;
  }

  for (const entry of entries) {
    if (!entry.isFile() || !entry.name.endsWith(".md")) continue;
    const filePath = join(roleDir, entry.name);
    const validation = validateRoleFile(filePath, options);
    result.warnings.push(...validation.warnings);
    if (validation.valid) {
      result.roles.push(validation.role);
    } else {
      result.invalidRoles.push({ filePath, validation });
    }
  }

  result.roles.sort((a, b) => a.name.localeCompare(b.name));
  result.invalidRoles.sort((a, b) => a.filePath.localeCompare(b.filePath));
  return result;
}

export function formatRoleWarning(warning) {
  const source = warning.sourcePath ? `${warning.sourcePath}: ` : "";
  return `role-manager: ${source}${warning.message}`;
}
