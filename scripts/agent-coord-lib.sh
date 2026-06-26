# Shared helpers for pi-env coordination commands.

coord_die() {
  printf 'agent-coord: %s\n' "$*" >&2
  exit 1
}

coord_note() {
  printf 'agent-coord: %s\n' "$*" >&2
}

coord_deprecated() {
  coord_note "deprecated: $*"
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

coord_default_root_for_project() {
  local project_root pi_env_root legacy_root
  project_root="$(coord_project_root)"
  pi_env_root="$project_root/.pi-env/agent-remotes"
  legacy_root="$project_root/agent-remotes"

  if [ -d "$pi_env_root" ]; then
    printf '%s\n' "$pi_env_root"
  elif [ -d "$legacy_root" ]; then
    printf '%s\n' "$legacy_root"
  else
    printf '%s\n' "$pi_env_root"
  fi
}

coord_default_root() {
  if [ -n "${PI_COORD_ROOT:-}" ]; then
    printf '%s\n' "$PI_COORD_ROOT"
    return
  fi

  coord_default_root_for_project
}

coord_default_workspace() {
  if [ -n "${PI_COORD_WORKSPACE:-}" ]; then
    coord_deprecated "PI_COORD_WORKSPACE is a compatibility alias; use PI_COORD_PROJECT instead"
    printf '%s\n' "$PI_COORD_WORKSPACE"
  else
    basename "$(pwd -P)"
  fi
}

coord_default_dir_for_project() {
  local project_root pi_env_dir legacy_dir
  project_root="$(coord_project_root)"
  pi_env_dir="$project_root/.pi-env/coordination"
  legacy_dir="$project_root/coordination"

  if [ -d "$pi_env_dir" ]; then
    printf '%s\n' "$pi_env_dir"
  elif [ -d "$legacy_dir" ]; then
    printf '%s\n' "$legacy_dir"
  else
    printf '%s\n' "$pi_env_dir"
  fi
}

coord_default_dir() {
  if [ -n "${PI_COORD_DIR:-}" ]; then
    printf '%s\n' "$PI_COORD_DIR"
  else
    coord_default_dir_for_project
  fi
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

coord_item_type_canonical() {
  local type canonical
  type="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$type" in
    issue|issues)
      canonical="issue"
      ;;
    functional|functionals|functional-req|functional-reqs|functional_req|functional_reqs|functional-requirement|functional-requirements|functional_requirement|functional_requirements|frq|frqs)
      canonical="functional-requirement"
      ;;
    quality|qualities|quality-req|quality-reqs|quality_req|quality_reqs|quality-requirement|quality-requirements|quality_requirement|quality_requirements|qrq|qrqs)
      canonical="quality-requirement"
      ;;
    constraint|constraints|constraint-req|constraint-reqs|constraint_req|constraint_reqs|constraint-requirement|constraint-requirements|constraint_requirement|constraint_requirements|crq|crqs)
      canonical="constraint-requirement"
      ;;
    requirement|requirements|req|reqs)
      canonical="requirement"
      ;;
    todo|todos)
      canonical="todo"
      ;;
    decision|decisions|dec)
      canonical="decision"
      ;;
    note|notes)
      canonical="note"
      ;;
    *)
      canonical="$(coord_sanitize_path_part "$type")"
      [ -n "$canonical" ] || canonical="item"
      ;;
  esac
  printf '%s\n' "$canonical"
}

coord_item_type_code() {
  local type code
  type="$(coord_item_type_canonical "$1")"
  case "$type" in
    issue|issues)
      code="ISS"
      ;;
    functional-requirement|functional-requirements)
      code="FRQ"
      ;;
    quality-requirement|quality-requirements)
      code="QRQ"
      ;;
    constraint-requirement|constraint-requirements)
      code="CRQ"
      ;;
    requirement|requirements|req|reqs)
      code="REQ"
      ;;
    todo|todos)
      code="TODO"
      ;;
    decision|decisions|dec)
      code="DEC"
      ;;
    note|notes)
      code="NOTE"
      ;;
    *)
      code="$(printf '%s' "$type" \
        | tr '[:lower:]' '[:upper:]' \
        | sed -E 's/[^A-Z0-9]+//g' \
        | cut -c1-4)"
      [ -n "$code" ] || code="ITEM"
      ;;
  esac
  printf '%s\n' "$code"
}

coord_item_type_dir() {
  local type dir
  type="$(coord_item_type_canonical "$1")"
  case "$type" in
    issue|issues)
      dir="issues"
      ;;
    functional-requirement|functional-requirements|quality-requirement|quality-requirements|constraint-requirement|constraint-requirements|requirement|requirements|req|reqs)
      dir="requirements"
      ;;
    todo|todos)
      dir="todos"
      ;;
    decision|decisions|dec)
      dir="decisions"
      ;;
    note|notes)
      dir="notes"
      ;;
    *)
      dir="$(coord_sanitize_path_part "$type")"
      [ -n "$dir" ] || dir="items"
      case "$dir" in
        *s) ;;
        *) dir="${dir}s" ;;
      esac
      ;;
  esac
  printf '%s\n' "$dir"
}

coord_item_type_uses_issue_status_dirs() {
  local type
  type="$(coord_item_type_canonical "$1")"
  case "$type" in
    issue|issues)
      return 0
      ;;
  esac
  return 1
}

coord_category_canonical() {
  local type canonical
  type="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$type" in
    feature|feature_request|feature-request|features|feature_requests|feature-requests)
      canonical="feature-request"
      ;;
    bug|bugs|defect|defects)
      canonical="bug"
      ;;
    task|tasks)
      canonical="task"
      ;;
    question|questions)
      canonical="question"
      ;;
    improvement|improvements|enhancement|enhancements)
      canonical="improvement"
      ;;
    *)
      canonical="$(coord_sanitize_path_part "$type")"
      ;;
  esac
  printf '%s\n' "$canonical"
}

coord_item_id_exists() {
  local candidate file id_value stem
  candidate="$1"
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    id_value="$(coord_item_value "$file" id || true)"
    if [ "$id_value" = "$candidate" ]; then
      return 0
    fi
    stem="$(basename "$file")"
    stem="${stem%.yaml}"
    stem="${stem%.yml}"
    stem="${stem%.md}"
    if [ "$stem" = "$candidate" ]; then
      return 0
    fi
  done < <(coord_item_find_files)
  return 1
}

coord_next_item_id() {
  local key type timestamp code base n suffix candidate
  key="$1"
  type="$2"
  timestamp="$3"
  code="$(coord_item_type_code "$type")"
  base="$key-$code-$timestamp"
  n=1
  while [ "$n" -le 999 ]; do
    suffix="$(printf '%03d' "$n")"
    candidate="$base-$suffix"
    if ! coord_item_id_exists "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
    n=$((n + 1))
  done
  coord_die "no unused item ID suffix below 1000 for $base"
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

coord_local_remote_url_for_clone() {
  local coord_dir remote_path rel
  coord_dir="$(coord_abs "$1")"
  remote_path="$(coord_abs "$2")"
  if rel="$(realpath -m --relative-to="$coord_dir" "$remote_path" 2>/dev/null)"; then
    case "$rel" in
      /*|'') printf '%s\n' "$remote_path" ;;
      *) printf '%s\n' "$rel" ;;
    esac
  else
    printf '%s\n' "$remote_path"
  fi
}

coord_ensure_operational_root_excluded() {
  local target_dir project_root target_abs pi_env_root exclude_path
  target_dir="$1"
  project_root="$(coord_project_root)"
  target_abs="$(coord_abs "$target_dir")"
  pi_env_root="$(coord_abs "$project_root/.pi-env")"

  case "$target_abs" in
    "$pi_env_root"|"$pi_env_root"/*) ;;
    *) return 0 ;;
  esac

  exclude_path="$(git -C "$project_root" rev-parse --git-path info/exclude 2>/dev/null || true)"
  [ -n "$exclude_path" ] || return 0
  mkdir -p "$(dirname "$exclude_path")"
  touch "$exclude_path"
  if ! grep -Fxq '/.pi-env/' "$exclude_path"; then
    printf '/.pi-env/\n' >>"$exclude_path"
  fi
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
  local candidate git_root project_root
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
    project_root="$(coord_project_root)"
    if [ -d "$project_root/.pi-env/coordination" ]; then
      candidate="$project_root/.pi-env/coordination"
    elif [ -d "$project_root/coordination" ]; then
      candidate="$project_root/coordination"
    else
      candidate="$project_root/.pi-env/coordination"
    fi
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

coord_move_issue_item_to_status() {
  local item_path target_status target_path
  item_path="$1"
  target_status="$2"
  target_path="$item_path"

  case "$item_path" in
    issues/open/*)
      target_path="issues/$target_status/${item_path#issues/open/}"
      ;;
    issues/blocked/*)
      target_path="issues/$target_status/${item_path#issues/blocked/}"
      ;;
    issues/done/*)
      target_path="issues/$target_status/${item_path#issues/done/}"
      ;;
    issues/closed/*)
      target_path="issues/$target_status/${item_path#issues/closed/}"
      ;;
    */issues/open/*)
      target_path="${item_path/\/issues\/open\//\/issues\/$target_status\/}"
      ;;
    */issues/blocked/*)
      target_path="${item_path/\/issues\/blocked\//\/issues\/$target_status\/}"
      ;;
    */issues/done/*)
      target_path="${item_path/\/issues\/done\//\/issues\/$target_status\/}"
      ;;
    */issues/closed/*)
      target_path="${item_path/\/issues\/closed\//\/issues\/$target_status\/}"
      ;;
  esac

  if [ "$target_path" != "$item_path" ]; then
    mkdir -p "$(dirname "$target_path")"
    if git ls-files --error-unmatch -- "$item_path" >/dev/null 2>&1; then
      git mv "$item_path" "$target_path"
    else
      mv "$item_path" "$target_path"
    fi
    item_path="$target_path"
  fi

  printf '%s\n' "$item_path"
}

coord_item_flag_true() {
  local file key value
  file="$1"
  key="$2"
  value="$(coord_item_value "$file" "$key" | tr '[:upper:]' '[:lower:]')"
  case "$value" in
    true|yes|1)
      return 0
      ;;
  esac
  return 1
}

coord_yaml_quote() {
  local value
  value="$(printf '%s' "$1" | sed "s/'/''/g")"
  printf "'%s'" "$value"
}

coord_yaml_scalar() {
  local value
  value="$1"
  if [ -z "$value" ]; then
    printf 'null'
  elif printf '%s' "$value" | grep -Eq '^[A-Za-z0-9_.@/+:-]+$'; then
    printf '%s' "$value"
  else
    coord_yaml_quote "$value"
  fi
}

coord_yaml_unquote() {
  local value first last
  value="$(coord_trim "$1")"
  case "$value" in
    ""|null|Null|NULL|~)
      printf '\n'
      return
      ;;
  esac
  first="${value:0:1}"
  last="${value: -1}"
  if [ "$first" = "'" ] && [ "$last" = "'" ] && [ "${#value}" -ge 2 ]; then
    value="${value:1:${#value}-2}"
    value="$(printf '%s' "$value" | sed "s/''/'/g")"
  elif [ "$first" = '"' ] && [ "$last" = '"' ] && [ "${#value}" -ge 2 ]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s\n' "$value"
}

coord_frontmatter_value() {
  local file key value
  file="$1"
  key="$2"
  value="$(awk -v key="$key" '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && index($0, key ":") == 1 {
      sub("^[^:]+:[[:space:]]*", "")
      print
      exit
    }
  ' "$file")"
  coord_yaml_unquote "$value"
}

coord_item_value() {
  local file key value
  file="$1"
  key="$2"
  value="$(awk -v key="$key" '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && index($0, key ":") == 1 {
      sub("^[^:]+:[[:space:]]*", "")
      print
      exit
    }
    NR == 1 && $0 != "---" { top = 1 }
    top && index($0, key ":") == 1 {
      sub("^[^:]+:[[:space:]]*", "")
      print
      exit
    }
  ' "$file")"
  coord_yaml_unquote "$value"
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

coord_metadata_value() {
  local file key value
  file="$1"
  key="$2"
  value=""
  if [ -f "$file" ]; then
    value="$(coord_frontmatter_value "$file" "$key" || true)"
  fi
  printf '%s\n' "$value"
}

coord_has_legacy_layout() {
  [ -f WORKSPACE.md ] || [ -d workspace ] || [ -d projects ]
}

coord_has_legacy_workspace_layout() {
  [ -f WORKSPACE.md ] || [ -d workspace ]
}

coord_has_project_root_layout() {
  [ -f PROJECT.md ] && {
    [ -d issues ] || [ -d requirements ] || [ -d todos ] \
      || [ -d decisions ] || [ -d notes ]
  }
}

coord_write_root_items_by_default() {
  coord_has_project_root_layout
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

coord_set_item_values() {
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
    !inserted && ($0 == "current:" || $0 == "events:" || $0 == "messages:") {
      for (i = 1; i <= n; i++) {
        key = key_list[i]
        if (!found[key]) {
          print key ": " wanted[key]
          found[key] = 1
        }
      }
      inserted = 1
    }
    {
      for (i = 1; i <= n; i++) {
        key = key_list[i]
        if (index($0, key ":") == 1) {
          print key ": " wanted[key]
          found[key] = 1
          next
        }
      }
      print
    }
    END {
      if (!inserted) {
        for (i = 1; i <= n; i++) {
          key = key_list[i]
          if (!found[key]) {
            print key ": " wanted[key]
          }
        }
      }
    }
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
}

coord_set_current_pointers() {
  local file event_id message_id tmp
  file="$1"
  event_id="$2"
  message_id="$3"
  tmp="$(mktemp)"
  awk -v event_id="$event_id" -v message_id="$message_id" '
    /^current:[[:space:]]*$/ {
      in_current = 1
      saw_current = 1
      saw_event = 0
      saw_message = 0
      print
      next
    }
    in_current && /^  event:/ {
      print "  event: " event_id
      saw_event = 1
      next
    }
    in_current && /^  message:/ {
      print "  message: " message_id
      saw_message = 1
      next
    }
    in_current && /^[^[:space:]]/ {
      if (!saw_event) print "  event: " event_id
      if (!saw_message) print "  message: " message_id
      in_current = 0
    }
    !saw_current && ($0 == "events:" || $0 == "messages:") {
      print "current:"
      print "  event: " event_id
      print "  message: " message_id
      saw_current = 1
    }
    { print }
    END {
      if (in_current) {
        if (!saw_event) print "  event: " event_id
        if (!saw_message) print "  message: " message_id
      } else if (!saw_current) {
        print "current:"
        print "  event: " event_id
        print "  message: " message_id
      }
    }
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
}

coord_next_event_id() {
  local file
  file="$1"
  awk '
    /^[[:space:]]*- id: evt-[0-9]+/ {
      value = $0
      sub(/^.*evt-/, "", value)
      sub(/[^0-9].*$/, "", value)
      n = value + 0
      if (n > max) max = n
    }
    END { printf "evt-%04d\n", max + 1 }
  ' "$file"
}

coord_message_id_for_event() {
  local event_id number
  event_id="$1"
  number="${event_id#evt-}"
  printf 'msg-%s\n' "$number"
}

coord_write_implementation_ref_yaml() {
  local indent ref repo rest branch commit
  indent="$1"
  ref="$2"

  repo="${ref%%:*}"
  if [ "$repo" = "$ref" ]; then
    coord_die "invalid implementation ref, expected repo:branch@full-commit: $ref"
  fi
  rest="${ref#*:}"
  branch="${rest%@*}"
  commit="${rest##*@}"
  if [ "$branch" = "$rest" ]; then
    coord_die "invalid implementation ref, expected repo:branch@full-commit: $ref"
  fi
  if [ -z "$repo" ] || [ -z "$branch" ] || [ -z "$commit" ]; then
    coord_die "invalid implementation ref, expected repo:branch@full-commit: $ref"
  fi
  if ! [[ "$commit" =~ ^[0-9A-Fa-f]{40}$ ]]; then
    coord_die "implementation ref commit must be a full 40-character hash: $ref"
  fi

  printf '%s- repo: %s\n' "$indent" "$(coord_yaml_scalar "$repo")"
  printf '%s  branch: %s\n' "$indent" "$(coord_yaml_scalar "$branch")"
  printf '%s  commit: %s\n' "$indent" "$(coord_yaml_scalar "$commit")"
}

coord_append_item_event_message() {
  local file event_id event_type timestamp agent_id role message_id body tmp event_tmp message_tmp ref
  file="$1"
  event_id="$2"
  event_type="$3"
  timestamp="$4"
  agent_id="$5"
  role="$6"
  message_id="$7"
  body="$8"
  shift 8

  event_tmp="$(mktemp)"
  message_tmp="$(mktemp)"
  tmp="$(mktemp)"

  {
    printf '  - id: %s\n' "$event_id"
    printf '    type: %s\n' "$event_type"
    printf '    at: %s\n' "$timestamp"
    printf '    actor:\n'
    printf '      id: %s\n' "$(coord_yaml_scalar "$agent_id")"
    printf '      role: %s\n' "$(coord_yaml_scalar "$role")"
    printf '    message: %s\n' "$message_id"
    if [ "$event_type" = "claimed" ]; then
      printf '    owner: %s\n' "$(coord_yaml_scalar "$agent_id")"
    fi
    if [ "$#" -gt 0 ]; then
      printf '    implementation_refs:\n'
      for ref in "$@"; do
        [ -n "$ref" ] || continue
        coord_write_implementation_ref_yaml "      " "$ref"
      done
    fi
  } >"$event_tmp"

  {
    printf '  - id: %s\n' "$message_id"
    printf '    event: %s\n' "$event_id"
    printf '    body: |-\n'
    if [ -n "$body" ]; then
      printf '%s\n' "$body" | sed -e 's/^/      /' -e 's/^      $//'
    else
      printf '      \n'
    fi
  } >"$message_tmp"

  awk -v event_file="$event_tmp" -v message_file="$message_tmp" '
    /^messages:[[:space:]]*$/ && !inserted_event {
      while ((getline line < event_file) > 0) print line
      close(event_file)
      inserted_event = 1
    }
    { print }
    END {
      if (!inserted_event) {
        print "events:"
        while ((getline line < event_file) > 0) print line
        close(event_file)
        print "messages:"
      }
      while ((getline line < message_file) > 0) print line
      close(message_file)
    }
  ' "$file" >"$tmp"

  mv "$tmp" "$file"
  rm -f "$event_tmp" "$message_tmp"
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

coord_item_find_files() {
  local roots=() seen file id_value stem key
  for root in issues requirements todos decisions notes workspace projects; do
    if [ -e "$root" ]; then
      roots+=("$root")
    fi
  done
  [ "${#roots[@]}" -gt 0 ] || return 0

  seen=$'\n'
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    id_value="$(coord_item_value "$file" id || true)"
    if [ -n "$id_value" ]; then
      key="$id_value"
    else
      stem="$(basename "$file")"
      stem="${stem%.yaml}"
      stem="${stem%.yml}"
      stem="${stem%.md}"
      key="$stem"
    fi
    case "$seen" in
      *$'\n'"$key"$'\n'*) continue ;;
    esac
    seen="${seen}${key}"$'\n'
    printf '%s\n' "$file"
  done < <(find "${roots[@]}" \
    -type f \
    \( -name '*.yaml' -o -name '*.yml' -o -name '*.md' \) \
    2>/dev/null | sort)
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
      "$query"|"$query".md|"$query".yaml|"$query".yml|"$query"-*)
        matches="${matches}${file}"$'\n'
        continue
        ;;
    esac
    id_value="$(coord_item_value "$file" id || true)"
    if [ "$id_value" = "$query" ]; then
      matches="${matches}${file}"$'\n'
    fi
  done < <(coord_item_find_files)

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
