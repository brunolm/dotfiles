## Zips the untracked .env*, *.local.* and docs/local files of every git repo under a folder,
## keeping the folder structure so the zip unpacks on top of fresh clones.
## Usage: backup-projects-local [path] [output.zip] [--dry-run]

BACKUP_SKIP_DIRS=(
  .git node_modules bower_components vendor
  .venv venv __pycache__ .tox .mypy_cache .pytest_cache
  dist built build out target .next .nuxt .svelte-kit .turbo .parcel-cache
  coverage .cache
  .gradle .idea .vs
)
# Matched against the last two path segments, so a project called "obj" is still scanned.
BACKUP_SKIP_PAIRS=(bin/Debug bin/Release obj/Debug obj/Release)
BACKUP_LOCAL_DIRS=(docs/local)

backup-projects-local() {
  local path='.' output='projects-local-backup.zip' dry_run=0 arg positional=0
  for arg in "$@"; do
    case "$arg" in
      --dry-run|-n) dry_run=1 ;;
      *)
        positional=$((positional + 1))
        [[ $positional -eq 1 ]] && path="$arg"
        [[ $positional -eq 2 ]] && output="$arg"
        ;;
    esac
  done
  [[ -d "$path" ]] || { echo "Folder '$path' does not exist." >&2; return 1; }
  if (( ! dry_run )) && ! command -v zip >/dev/null; then
    echo "zip is not installed (sudo apt install zip)." >&2
    return 1
  fi

  local root
  root=$(realpath "$path")
  local files=()
  mapfile -t files < <(backup-find-local-files "$root" | sort)
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No untracked local files found under $root."
    return
  fi

  local repo='' file
  for file in "${files[@]}"; do
    if [[ "${file%%$'\t'*}" != "$repo" ]]; then
      repo="${file%%$'\t'*}"
      printf '\n%s\n' "$repo"
    fi
    printf '  %s\n' "${file#*$'\t'}"
  done
  echo
  if (( dry_run )); then
    echo "Dry run: ${#files[@]} files would be zipped."
    return
  fi

  local zip_path
  zip_path=$(realpath -m "$output")
  rm -f "$zip_path"
  (cd "$root" && printf '%s\n' "${files[@]#*$'\t'}" | zip -q "$zip_path" -@)
  echo "Wrote ${#files[@]} files to $zip_path"
  echo "Unzip it into $root to restore."
}

# Prints "<repo>\t<path relative to root>" for every untracked local file.
backup-find-local-files() {
  local root="$1" repos=() repo rel file
  mapfile -d '' repos < <(find "$root" \( -name .git -printf '%h\0' -prune \) -o "${_backup_prune[@]}" 2>/dev/null)

  for repo in "${repos[@]}"; do
    declare -A tracked=()
    while IFS= read -r -d '' rel; do tracked["$rel"]=1; done < <(git -C "$repo" ls-files -z 2>/dev/null)
    while IFS= read -r -d '' file; do
      rel="${file#"$repo"/}"
      [[ -n "${tracked[$rel]:-}" ]] && continue
      printf '%s\t%s\n' "$repo" "${file#"$root"/}"
    done < <(backup-find-candidates "$repo" "${repos[@]}")
  done
}

# Nested repos are pruned so their files are attributed to the repo that owns them.
backup-find-candidates() {
  local repo="$1" other nested=() local_dir_paths=() dir
  shift
  for other in "$@"; do
    [[ "$other" == "$repo"/* ]] && nested+=(-o -path "$other")
  done
  for dir in "${BACKUP_LOCAL_DIRS[@]}"; do
    local_dir_paths+=(-o -path "*/$dir/*")
  done
  find "$repo" \
    "${_backup_prune[@]}" \
    -o \( -type d -false "${nested[@]}" \) -prune \
    -o \( -type d \( -name bin -o -name obj \) -exec bash -c 'ls "$(dirname "$1")"/*.*proj >/dev/null 2>&1' _ '{}' \; \) -prune \
    -o -type f \( -iname '.env' -o -iname '.env.*' -o -name '*.local.*' "${local_dir_paths[@]}" \) -print0 \
    2>/dev/null
}

_backup_build_prune() {
  local name expr=(-type d \()
  local first=1
  for name in "${BACKUP_SKIP_DIRS[@]}"; do
    (( first )) || expr+=(-o)
    expr+=(-name "$name")
    first=0
  done
  for name in "${BACKUP_SKIP_PAIRS[@]}"; do
    expr+=(-o -path "*/$name")
  done
  expr+=(\) -prune)
  _backup_prune=("${expr[@]}")
}
_backup_build_prune
