#!/bin/bash

# Global commands behind "docker >": prune resources, set the docker binary
# path, and updates. The autoupdate helpers come from the shared, fetched
# src/autoupdate.sh.

. src/media.sh
. src/autoupdate.sh
. src/containers.sh

# Lowercase a string.
docker_lower() {
  local text="$1"
  printf '%s' "$text" | tr '[:upper:]' '[:lower:]'
  return 0
}

# Queue a global command when its token contains the filter (case-insensitive).
# $1 token  $2 filter  $3 title  $4 subtitle  $5 arg  $6 valid  $7 icon  $8 autocomplete
global_item() {
  local token="$1" filter="$2" title="$3" subtitle="$4" arg="$5" valid="$6" icon="$7" auto="$8"
  case "$(docker_lower "$token")" in
    *"$(docker_lower "$filter")"*) add_result "" "$arg" "$title" "$subtitle" "$icon" "$valid" "$auto" ;;
    *) : ;;
  esac
  return 0
}

# The global command menu, filtered by a substring.
globals_menu() {
  local filter="$1"
  global_item "prune stopped containers" "$filter" "Prune stopped containers" "Remove all stopped containers" "prune-containers" "yes" "$ICON_TRASH" ""
  global_item "prune dangling images"    "$filter" "Prune dangling images"    "Remove unused image layers"    "prune-images"     "yes" "$ICON_TRASH" ""
  global_item "system prune"             "$filter" "System prune"             "Remove stopped containers, networks, and dangling images" "prune-system" "yes" "$ICON_TRASH" ""
  global_item "set docker path"          "$filter" "Set docker binary path"   "Edit the path if docker is not auto-detected" "set-path" "yes" "$ICON_GEAR" ""
  autoupdate_menu "$filter" "$ICON_UPDATE"
  get_json_results
  return 0
}

# Open the docker-path config file in a text editor, seeding a comment.
edit_path() {
  local file
  file="$(path_config)"
  mkdir -p "${alfred_workflow_data:-.}"
  [[ -f "$file" ]] || printf '# Full path to the docker binary, one line. Example:\n# /usr/local/bin/docker\n' > "$file"
  open -e "$file"
  return 0
}
