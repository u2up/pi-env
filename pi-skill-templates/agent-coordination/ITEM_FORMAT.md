# Coordination Item Format

Coordination items are Markdown files with YAML-style frontmatter.

## Filename IDs

Use stable IDs in filenames. For high-concurrency agent-created items,
prefer timestamp IDs to avoid number allocation races:

```text
<PROJECTKEY>-<YYYYMMDD-HHMMSS>-<slug>.md
```

`PROJECTKEY` should be uppercase alphanumeric text. Project item keys are
stored in `projects/<project>/PROJECT.md` as `item_key`. Workspace-level
item keys are stored in top-level `WORKSPACE.md` as `item_key`.

When `agent-coord-new` needs to derive a key, it uppercases the source name
and removes delimiters, whitespace, slashes, backslashes, pipes, and other
non-alphanumeric characters. Project items derive from the project name;
workspace-level items derive from the workspace directory name.

Example:

```text
PIENV-20260605-143022-document-pi-config.md
```

Sequential IDs are acceptable for smaller human-managed repositories:

```text
PIENV-0001-document-pi-config.md
```

## Frontmatter

Each item repeats its ID and state in frontmatter:

```markdown
---
id: PIENV-20260605-143022
type: issue
status: open
project: pi-env
owner:
priority: medium
created: 2026-06-05T14:30:22Z
updated: 2026-06-05T14:30:22Z
closed:
related: []
---

# Document pi config behavior

## Context

## Acceptance criteria

- [ ] README explains host `pi config`.
- [ ] README explains sandbox `pi-bwrap -- config`.

## Activity

- 2026-06-05T14:30:22Z agent-a: Created.
```

## Directories and status

Keep open, blocked, and closed work in separate directories and also keep
status in frontmatter:

```text
issues/open/
issues/blocked/
issues/closed/
```

When closing an issue, use `git mv`, set `status: closed`, set `closed:`,
and append the result to `## Activity`.
