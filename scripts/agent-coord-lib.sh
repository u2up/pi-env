# Shared helpers for pi-env coordination commands.

coord_die() {
  printf 'agent-coord: %s\n' "$*" >&2
  exit 1
}

coord_note() {
  printf 'agent-coord: %s\n' "$*" >&2
}

coord_abs() {
  realpath -m "$1"
}

coord_project_root() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$root" ]; then
    root="$(pwd -P)"
  fi
  coord_abs "$root"
}

coord_default_root() {
  local project_root workspace_root
  if [ -n "${PI_COORD_ROOT:-}" ]; then
    printf '%s\n' "$PI_COORD_ROOT"
    return
  fi

  project_root="$(coord_project_root)"
  if [ -d /workspace ]; then
    workspace_root="$(coord_abs /workspace)"
    if [ "$project_root" = "/workspace" ] || [ "$project_root" = "$workspace_root" ]; then
      printf '%s\n' "/workspace/agent-remotes"
      return
    fi
  fi

  if [ -n "$project_root" ]; then
    printf '%s\n' "$project_root/agent-remotes"
  elif [ -n "${HOME:-}" ]; then
    printf '%s\n' "$HOME/agent-remotes"
  else
    printf '%s\n' "./agent-remotes"
  fi
}

coord_default_workspace() {
  if [ -n "${PI_COORD_WORKSPACE:-}" ]; then
    printf '%s\n' "$PI_COORD_WORKSPACE"
  else
    basename "$(pwd -P)"
  fi
}

coord_default_dir() {
  printf '%s\n' "${PI_COORD_DIR:-coordination}"
}

coord_default_agent() {
  if [ -n "${PI_COORD_AGENT_ID:-}" ]; then
    printf '%s\n' "$PI_COORD_AGENT_ID"
  elif [ -n "${USER:-}" ]; then
    printf '%s\n' "$USER"
  else
    printf '%s\n' "agent"
  fi
}

coord_default_role() {
  printf '%s\n' "${PI_COORD_ROLE:-}"
}

coord_trim() {
  printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

coord_effective_actor() {
  local agent role
  agent="$(coord_trim "$1")"
  role="$(coord_trim "$2")"

  if [ -n "$agent" ] && [ -n "$role" ]; then
    printf '%s/%s\n' "$agent" "$role"
  elif [ -n "$role" ]; then
    printf '%s\n' "$role"
  else
    printf '%s\n' "$agent"
  fi
}

coord_actor_email() {
  local actor local_part
  actor="$1"
  local_part="$(printf '%s' "$actor" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[[:space:]\/]+/+/g; s/[^a-z0-9._+%-]+/-/g; s/^[^a-z0-9]+//; s/[^a-z0-9]+$//')"
  if [ -z "$local_part" ]; then
    local_part="coordination"
  fi
  printf '%s@coordination.local\n' "$local_part"
}

coord_git_commit() {
  local actor email
  actor="$1"
  shift

  if [ -n "$actor" ]; then
    email="$(coord_actor_email "$actor")"
    git -c "user.name=$actor" -c "user.email=$email" commit "$@"
  else
    git commit "$@"
  fi
}

coord_template_dir() {
  local script_dir
  if [ -n "${PI_ENV_COORD_TEMPLATE_DIR:-}" ]; then
    printf '%s\n' "$PI_ENV_COORD_TEMPLATE_DIR"
    return
  fi
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  printf '%s\n' "$(coord_abs "$script_dir/../pi-skill-templates/agent-coordination")"
}

coord_sanitize_path_part() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

coord_project_id_prefix() {
  local value prefix
  value="$1"
  prefix="$(printf '%s' "$value" \
    | tr '[:lower:]' '[:upper:]' \
    | sed -E 's/[^A-Z0-9]+//g')"
  if [ -z "$prefix" ]; then
    prefix="ITEM"
  fi
  printf '%s\n' "$prefix"
}

coord_workspace_dir_key() {
  local coord_dir parent key
  coord_dir="$(coord_abs "$1")"
  parent="$(dirname "$coord_dir")"
  key="$(basename "$parent")"
  if [ -z "$key" ] || [ "$key" = "/" ]; then
    key="${PI_COORD_WORKSPACE:-workspace}"
  fi
  printf '%s\n' "$key"
}

coord_metadata_item_key() {
  local file value
  file="$1"
  value=""
  if [ -f "$file" ]; then
    value="$(coord_frontmatter_value "$file" item_key || true)"
  fi
  printf '%s\n' "$value"
}

coord_slug() {
  local slug
  slug="$(printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g' \
    | cut -c1-60)"
  if [ -z "$slug" ]; then
    slug="item"
  fi
  printf '%s\n' "$slug"
}

coord_timestamp_id() {
  date -u +%Y%m%d-%H%M%S
}

coord_timestamp_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

coord_remote_for() {
  local root workspace
  root="$1"
  workspace="$2"
  printf '%s/%s-coordination.git\n' "$root" "$workspace"
}

coord_is_coord_repo() {
  local dir
  dir="$1"
  [ -d "$dir/.git" ] \
    && [ -f "$dir/AGENTS.md" ] \
    && [ -f "$dir/docs/SYNC_PROTOCOL.md" ] \
    && [ -f "$dir/docs/ITEM_FORMAT.md" ]
}

coord_resolve_dir() {
  local candidate git_root
  candidate="${1:-}"
  if [ -z "$candidate" ] && [ -n "${PI_COORD_DIR:-}" ]; then
    candidate="$PI_COORD_DIR"
  fi
  if [ -z "$candidate" ]; then
    git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$git_root" ] && coord_is_coord_repo "$git_root"; then
      coord_abs "$git_root"
      return
    fi
    candidate="coordination"
  fi
  [ -d "$candidate" ] || coord_die "coordination dir not found: $candidate"
  candidate="$(coord_abs "$candidate")"
  [ -d "$candidate/.git" ] || coord_die "not a Git repo: $candidate"
  printf '%s\n' "$candidate"
}

coord_git_config_defaults() {
  git config pull.rebase true
  git config rebase.autoStash true
}

coord_install_template() {
  local source_name target template_dir target_dir
  source_name="$1"
  target="$2"
  template_dir="$(coord_template_dir)"
  [ -f "$template_dir/$source_name" ] \
    || coord_die "missing template: $template_dir/$source_name"
  target_dir="$(dirname "$target")"
  mkdir -p "$target_dir"
  cp "$template_dir/$source_name" "$target"
}

coord_git_has_head() {
  git rev-parse --verify HEAD >/dev/null 2>&1
}

coord_git_has_staged_changes() {
  ! git diff --cached --quiet --exit-code
}

coord_git_has_worktree_changes() {
  ! git diff --quiet --exit-code || [ -n "$(git ls-files --others --exclude-standard)" ]
}

coord_validate_subject() {
  local subject
  subject="$1"
  if [ "${#subject}" -gt 72 ]; then
    coord_die "commit subject exceeds 72 characters: $subject"
  fi
}

coord_commit_all_if_changed() {
  local message actor
  message="$1"
  actor="${2:-}"
  coord_validate_subject "$message"
  git add -A
  if coord_git_has_staged_changes; then
    coord_git_commit "$actor" -m "$message"
    return 0
  fi
  return 1
}

coord_pull_rebase() {
  if git remote get-url origin >/dev/null 2>&1; then
    git pull --rebase --autostash "$@"
  else
    coord_note "no origin remote configured; skipping pull"
  fi
}

coord_repo_path() {
  local path
  path="$1"
  realpath -m --relative-to="$(pwd -P)" "$path" 2>/dev/null || printf '%s\n' "$path"
}

coord_frontmatter_value() {
  local file key
  file="$1"
  key="$2"
  awk -v key="$key" '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && index($0, key ":") == 1 {
      sub("^[^:]+:[[:space:]]*", "")
      print
      exit
    }
  ' "$file"
}

coord_set_frontmatter() {
  local file tmp sep keys values pair key value
  file="$1"
  shift
  sep=$(printf '\037')
  keys=""
  values=""
  for pair in "$@"; do
    key="${pair%%=*}"
    value="${pair#*=}"
    keys="${keys}${sep}${key}"
    values="${values}${sep}${value}"
  done
  keys="${keys#${sep}}"
  values="${values#${sep}}"
  tmp="$(mktemp)"
  awk -v keys="$keys" -v values="$values" -v sep="$sep" '
    BEGIN {
      n = split(keys, key_list, sep)
      split(values, value_list, sep)
      for (i = 1; i <= n; i++) {
        wanted[key_list[i]] = value_list[i]
        found[key_list[i]] = 0
      }
    }
    NR == 1 && $0 == "---" {
      in_fm = 1
      print
      next
    }
    in_fm && $0 == "---" {
      for (i = 1; i <= n; i++) {
        key = key_list[i]
        if (!found[key]) {
          print key ": " wanted[key]
        }
      }
      in_fm = 0
      print
      next
    }
    in_fm {
      for (i = 1; i <= n; i++) {
        key = key_list[i]
        if (index($0, key ":") == 1) {
          print key ": " wanted[key]
          found[key] = 1
          next
        }
      }
      print
      next
    }
    { print }
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
}

coord_append_activity() {
  local file timestamp agent message
  file="$1"
  timestamp="$2"
  agent="$3"
  message="$4"
  message="$(printf '%s' "$message" | tr '\n' ' ')"
  if ! grep -q '^## Activity$' "$file"; then
    printf '\n## Activity\n' >>"$file"
  fi
  printf '\n- %s %s: %s\n' "$timestamp" "$agent" "$message" >>"$file"
}

coord_find_item() {
  local query match_count matches file id_value
  query="$1"
  if [ -f "$query" ]; then
    coord_abs "$query"
    return
  fi

  matches=""
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    case "$(basename "$file")" in
      "$query"|"$query".md|"$query"-*)
        matches="${matches}${file}"$'\n'
        continue
        ;;
    esac
    id_value="$(coord_frontmatter_value "$file" id || true)"
    if [ "$id_value" = "$query" ]; then
      matches="${matches}${file}"$'\n'
    fi
  done < <(find workspace projects -type f -name '*.md' 2>/dev/null | sort)

  match_count="$(printf '%s' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "$match_count" = "0" ]; then
    coord_die "item not found: $query"
  fi
  if [ "$match_count" != "1" ]; then
    printf 'agent-coord: multiple items match %s:\n%s' "$query" "$matches" >&2
    exit 1
  fi
  printf '%s' "$matches" | sed '/^$/d' | head -n 1
}
