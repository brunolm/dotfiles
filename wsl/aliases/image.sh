get-image-base64() {
  local file="$1"
  if [[ "$file" == http* ]]; then
    get-image-base64-url "$file"
  else
    get-image-base64-file "$file"
  fi
}

get-image-base64-file() {
  local file="$1"
  [[ -f "$file" ]] || { echo "File not found: $file" >&2; return 1; }
  local type
  type=$(file --mime-type -b "$file" 2>/dev/null)
  if [[ -z "$type" ]]; then
    local ext="${file##*.}"
    type="image/$ext"
  fi
  local b64; b64=$(base64 -w0 "$file")
  echo "data:${type};base64,${b64}"
}

get-image-base64-url() {
  local url="$1"
  local headers body type b64
  headers=$(mktemp); body=$(mktemp)
  curl -sSL -D "$headers" "$url" -o "$body"
  type=$(awk -F': ' 'tolower($1)=="content-type"{sub(/\r$/,"",$2); print $2; exit}' "$headers")
  b64=$(base64 -w0 "$body")
  rm -f "$headers" "$body"
  echo "data:${type};base64,${b64}"
}
