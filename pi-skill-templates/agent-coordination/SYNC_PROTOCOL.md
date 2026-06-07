# Coordination Git Synchronization Protocol

The coordination repository uses ordinary Git as the synchronization and
conflict-detection mechanism.

## Required flow

1. Pull/rebase before reading or selecting work:

   ```bash
   git pull --rebase
   ```

2. Claim one item by editing its YAML current-state fields:

   ```yaml
   status: claimed
   owner: <agent-id>
   updated: <timestamp>
   current:
     event: evt-XXXX
     message: msg-XXXX
   ```

3. Append a chronological `claimed` event with explicit actor/role metadata
   and a linked Markdown message under `messages:`.
4. Commit and push the claim immediately.
5. Do project work in the relevant project clone.
6. Pull/rebase the coordination repository again.
7. Update progress, blockers, links, result, or status by appending new
   events/messages and updating the top-level current-state fields.
8. When closing, move issue items to `closed/`, append a `closed` event, and
   include structured implementation refs with `repo`, `branch`, and full
   `commit` fields where possible.
9. Commit and push immediately.

## Recommended clone settings

Run these once in each coordination clone:

```bash
git config pull.rebase true
git config rebase.autoStash true
```

## Conflict handling

Git conflicts are the locking mechanism. If two agents claim or update the
same item, resolve the rebase or push conflict conservatively.

- Preserve factual updates from both sides when possible.
- Preserve chronological order in `events:` and `messages:`.
- Ask the user when ownership or stale-claim behavior is ambiguous.
- Never force-push or rewrite public coordination history.
- Keep commits small so conflicts remain easy to inspect.
