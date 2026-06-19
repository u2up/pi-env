# Item-matched tests

Executable scripts under this directory verify coordination items by filename
stem. The script name, without `.sh`, should match the coordination item `id`.

Root project issue tests live directly under `tests/items/`:

```text
tests/items/<item-id>.sh
```

Root project requirement tests use:

```text
tests/items/requirements/<item-id>.sh
```

Legacy project/workspace layouts remain accepted for older coordination
clones:

```text
tests/items/projects/<project>/<type-dir>/<item-id>.sh
tests/items/workspace/<type-dir>/<item-id>.sh
```

Keep scripts as plain bash and make each script executable. Use `tests/run.sh`
to run the standard suite plus any item-matched scripts.
