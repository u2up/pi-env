# pi-env role-manager package

This is the Pi role-manager resource package for pi-env role template support.

It currently provides:

- a documented role file schema (`ROLE_FILE_SCHEMA.md`);
- reusable schema validation helpers (`lib/role-schema.mjs`);
- role discovery, precedence, and active-role prompt helpers
  (`lib/role-loader.mjs`);
- a lightweight Pi extension that loads base, global/common, coordination,
  and project role files, reports warnings without failing Pi startup,
  provides `/role`, `/role-clear`, `/role-cycle`, and `/role-new`, registers
  the terminating `role_cycle_done` tool, applies active-role
  model/thinking/tool settings, injects only the active role body into the
  system prompt, and decorates the interactive UI with active-role status;
- base roles for `architect`, `developer`, `builder`, `tester`, and
  `reviewer`, each with its intended tool allowlist. The bundled
  `architect` role enables `read`, `grep`, `find`, `ls`, `bash`, `edit`, and
  `write` so architecture sessions can update Markdown/YAML documents and run
  coordination or Git commands.

Try it locally from this repository with:

```bash
pi -e ./role-manager
```

Inside the `pi-env` devshell, load the Nix-packaged role manager for one run
with:

```bash
pi-start -e "$PI_ENV_ROLE_MANAGER_PACKAGE"
```

Or install that package path into project-local Pi settings:

```bash
pi-bwrap install -l "$PI_ENV_ROLE_MANAGER_PACKAGE"
```

Role merge order is base package roles, global agent roles, common agent
roles, coordination workspace roles, and project `.pi/roles`, with later
sources overriding earlier sources by `name`. Discovery runs on session start,
so Pi's normal `/reload` flow refreshes role files.

The loader reads active role state from `role-manager-state` custom session
entries, or from `PI_ROLE_MANAGER_ACTIVE_ROLE` / `PI_ACTIVE_ROLE` / `PI_ROLE`
when no session state has been recorded. Use:

```text
/role                       open an interactive role selector
/role <name>                activate a role in the current session
/role-clear                 clear the role and restore previous settings
/role-cycle <name> <goal>   activate a role and run one bounded cycle here
/role-new <name> <goal>     start a fresh session and run one cycle there
```

Role activation persists the active role plus the pre-role model, thinking
level, and tool selection in the Pi session. When a role requests tools, the
extension activates the requested tools that the host Pi runtime has
registered and reports a warning naming any missing tools instead of silently
ignoring them. `/role-cycle` sends a bounded
one-cycle kickoff prompt in the current session, enables `role_cycle_done` for
that cycle, and instructs the model to call it as the final action with a
structured summary. `/role-new` uses Pi's session replacement API, records the
parent session, names the fresh session with a role prefix, and starts the
cycle from the replacement-session context. While a role is active, the
extension updates the footer status and terminal title; while `/role-cycle` is
running, it also shows the role's one-cycle checklist above the editor.
`/role-clear` removes those UI decorations. While a role is active, the
extension also exports `PI_COORD_ROLE` to Pi subprocesses using the role's
`coordCommitter` value, or the role name when `coordCommitter` is omitted.
