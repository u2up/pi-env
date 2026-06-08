# Item-matched tests

Executable scripts under this directory verify coordination items by filename
stem. The script name, without `.sh`, should match the coordination item `id`.

Project item tests mirror project and item type, not issue status:

```text
tests/items/projects/<project>/issues/<item-id>.sh
tests/items/projects/<project>/functional-requirements/<item-id>.sh
tests/items/projects/<project>/quality-requirements/<item-id>.sh
tests/items/projects/<project>/constraint-requirements/<item-id>.sh
tests/items/projects/<project>/requirements/<item-id>.sh  # legacy REQ items
```

Workspace item tests use:

```text
tests/items/workspace/<type-dir>/<item-id>.sh
```

Keep scripts as plain bash and make each script executable. Use `tests/run.sh`
to run the standard suite plus any item-matched scripts.
