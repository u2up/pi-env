# pi-env role-manager package

This is the initial Pi role-manager resource package for pi-env role template
support.

It currently provides:

- a documented role file schema (`ROLE_FILE_SCHEMA.md`);
- reusable schema validation helpers (`lib/role-schema.mjs`);
- role discovery, precedence, and active-role prompt helpers
  (`lib/role-loader.mjs`);
- a lightweight Pi extension that loads base, global/common, coordination,
  and project role files, reports warnings without failing Pi startup, and
  injects only the active role body into the system prompt;
- base roles for `architect`, `developer`, `builder`, `tester`, and
  `reviewer`.

Try it locally with:

```bash
pi -e ./role-manager
```

Role merge order is base package roles, global agent roles, common agent
roles, coordination workspace roles, and project `.pi/roles`, with later
sources overriding earlier sources by `name`. Discovery runs on session start,
so Pi's normal `/reload` flow refreshes role files.

The loader reads active role state from `role-manager-state` custom session
entries, or from `PI_ROLE_MANAGER_ACTIVE_ROLE` / `PI_ACTIVE_ROLE` / `PI_ROLE`
when no session state has been recorded. Slash commands, one-cycle termination,
UI status, and coordination identity are implemented by later coordination
items.
