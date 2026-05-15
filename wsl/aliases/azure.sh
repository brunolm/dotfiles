az-pr-open() {
  local id="$1" title="$2" branch="$3"
  az repos pr create --title "$title" --work-items "$id" -t "$branch"
}
