#!/bin/bash

# Docker access layer: resolve the docker binary (Alfred's PATH is minimal),
# list containers as JSON, and remember iTerm2 sessions so a repeated shell or
# logs launch focuses the existing window instead of stacking new ones.

. src/cache.sh

# Path to the file that stores an optional docker binary path override.
path_config() {
  printf '%s/docker-path' "${alfred_workflow_data:-.}"
  return 0
}

# The configured docker path override, or nothing.
path_config_value() {
  local file
  file="$(path_config)"
  [[ -f "$file" ]] || return 0
  grep -vE '^[[:space:]]*(#|$)' "$file" 2>/dev/null | head -1
  return 0
}

# Resolve the docker binary. Prefer an explicit override, then $PATH, then the
# common Docker Desktop, Homebrew, and Colima locations. Fails if none exist.
docker_bin() {
  local override path found
  # Test hook: DOCKER_BIN, when set, is the only binary considered.
  if [[ -n "${DOCKER_BIN+x}" ]]; then
    [[ -n "$DOCKER_BIN" && -x "$DOCKER_BIN" ]] && { printf '%s' "$DOCKER_BIN"; return 0; }
    return 1
  fi
  override="$(path_config_value)"
  if [[ -n "$override" && -x "$override" ]]; then
    printf '%s' "$override"
    return 0
  fi
  found="$(command -v docker 2>/dev/null || true)"
  for path in "$found" \
    /usr/local/bin/docker /opt/homebrew/bin/docker \
    "$HOME/.docker/bin/docker" \
    /Applications/Docker.app/Contents/Resources/bin/docker; do
    if [[ -n "$path" && -x "$path" ]]; then
      printf '%s' "$path"
      return 0
    fi
  done
  return 1
}

# Print all containers as a JSON array (running and stopped). Prints "[]" when
# the daemon is up with no containers. Fails (no output) when docker is missing
# or the daemon is down, so the caller can show the right message.
list_containers_json() {
  local bin raw
  bin="$(docker_bin)" || return 1
  raw="$("$bin" ps -a --format '{{json .}}' 2>/dev/null)" || return 1
  [[ -n "$raw" ]] || { printf '[]'; return 0; }
  printf '%s' "$raw" | jq -s '.' 2>/dev/null
  return 0
}

# Print one container object (compact JSON) whose ID starts with the argument.
container_by_id() {
  local id="$1" json
  json="$(list_containers_json)" || return 0
  printf '%s' "$json" | jq -c --arg id "$id" 'map(select(.ID|startswith($id)))[0] // empty' 2>/dev/null
  return 0
}

# iTerm2 session ids: a JSON object mapping a marker to the id of the session
# opened for it, so a repeat launch focuses it instead of opening a new window.
iterm_file() {
  printf '%s/iterm.json' "${alfred_workflow_data:-.}"
  return 0
}

iterm_session_id() {
  local marker="$1" file
  file="$(iterm_file)"
  [[ -f "$file" ]] || return 0
  jq -r --arg m "$marker" '.[$m] // ""' < "$file" 2>/dev/null
  return 0
}

iterm_set_session_id() {
  local marker="$1" id="$2" file data
  file="$(iterm_file)"
  mkdir -p "${alfred_workflow_data:-.}"
  data="$(cat "$file" 2>/dev/null || echo '{}')"
  printf '%s' "$data" | jq -c --arg m "$marker" --arg i "$id" '.[$m] = $i' > "$file.tmp" 2>/dev/null \
    && mv "$file.tmp" "$file"
  return 0
}

# Run a state-changing docker verb on a container, discarding output.
docker_action() {
  local verb="$1" id="$2" bin
  bin="$(docker_bin)" || return 0
  case "$verb" in
    remove) "$bin" rm -f "$id" >/dev/null 2>&1 ;;
    *)      "$bin" "$verb" "$id" >/dev/null 2>&1 ;;
  esac
  return 0
}

# Prune docker resources.
docker_prune() {
  local what="$1" bin
  bin="$(docker_bin)" || return 0
  case "$what" in
    containers) "$bin" container prune -f >/dev/null 2>&1 ;;
    images)     "$bin" image prune -f >/dev/null 2>&1 ;;
    system)     "$bin" system prune -f >/dev/null 2>&1 ;;
    *) : ;;
  esac
  return 0
}

# Write "docker inspect" JSON to a temp file and open it in a text editor.
inspect_container() {
  local id="$1" bin tmp
  bin="$(docker_bin)" || return 0
  tmp="${alfred_workflow_cache:-/tmp}/inspect-$id.json"
  mkdir -p "$(dirname "$tmp")"
  "$bin" inspect "$id" > "$tmp" 2>/dev/null
  open -e "$tmp"
  return 0
}
