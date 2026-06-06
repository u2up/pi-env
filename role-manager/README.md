# pi-env role-manager package

This is the initial Pi role-manager resource package for pi-env role template
support.

It currently provides:

- a documented role file schema (`ROLE_FILE_SCHEMA.md`);
- reusable schema validation helpers (`lib/role-schema.mjs`);
- a lightweight Pi extension that validates bundled role files and reports
  warnings without failing Pi startup;
- base roles for `architect`, `developer`, `builder`, `tester`, and
  `reviewer`.

Try it locally with:

```bash
pi -e ./role-manager
```

Later coordination items extend this package with role discovery precedence,
slash commands, one-cycle termination, UI status, and coordination identity.
